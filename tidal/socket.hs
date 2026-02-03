import Sound.Tidal.Pattern 
import Sound.Tidal.Params (pR) 
import Sound.Tidal.Stream.Types
import GHC.Real (denominator, numerator)

import qualified Data.Map as Map
import Control.Concurrent.MVar (readMVar)
import Data.Maybe (fromMaybe)
import Data.List (intercalate, sortOn)

import Data.MessagePack
import System.Random (randomRIO)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import System.IO
import qualified Data.Vector as V
import qualified Data.Text as T

import Network.Socket as S
import System.IO

import Network.Socket as S
import qualified Network.Socket.ByteString as NSB
import Data.ByteString.Char8 (pack)

:{


hasClockId :: Event ValueMap -> Bool
hasClockId (Event _ _ _ eventMap) =
  case Data.Map.lookup "_id_" eventMap of
    Just (VS "clock") -> True
    _                 -> False


showId eventMap = case Data.Map.lookup "_id_" eventMap of
  Just (VS idVal) -> T.pack(idVal)
  _ -> "none" 

showS eventMap = case Data.Map.lookup "s" eventMap of
  Just (VS soundVal) -> T.pack(soundVal)
  _ -> "none" 

showNote eventMap = case Data.Map.lookup "note" eventMap of
  Just (VN noteVal) -> noteVal 
  _ -> 0.0 

--
--
ratioToObject :: Ratio Integer -> Object
ratioToObject = ObjectFloat . fromRational

-- ["event1"] = {
--   id = "1",
--   eventId = 2,
--   colStart = 8,
--   whole = {
--     start = 0,
--     stop = 1,
--   },
-- },
--

createEventMsgPackObjects (Event _ (Just (Arc ws we)) a@(Arc ps pe) e) colStart eventId=
  (ObjectMap $
     V.fromList
       [ (ObjectStr "id", ObjectStr (showId e))
       , (ObjectStr "eventId", ObjectInt eventId)
       , (ObjectStr "colStart", ObjectInt colStart)
       , ( ObjectStr "whole"
         , ObjectMap $
             V.fromList
               [ (ObjectStr "start", ratioToObject ws)
               , (ObjectStr "stop", ratioToObject we)
               ]
         )
       ]
  )

-- Show context of an event
-- showEventAll' e = show (context e) ++ uncurry (++) (showEvent' e)
createAllEventMsgPackObjects e = map (\ ctx -> createEventMsgPackObjects e (fst $ fst ctx) (snd $ fst ctx) ) (contextPosition $ context e)

-- Show everything, including event context
-- showAll' :: [Event ValueMap] -> String

sanitizeAll es = concatMap createAllEventMsgPackObjects $ sortOn part $ filter (not . hasClockId) es

streamActivePt' s arc = do
  pMap <- readMVar (sPMapMV s)
  cMap <- readMVar (sStateMV s)
  events <- ioEvents cMap pMap 
  return (sanitizeAll events)
  where
    showKV cMap (k, x) =  (query $ psPattern x) (State (arc) cMap)
    ioEvents cMap pMap = return (concatMap (showKV cMap) $ Map.toList pMap)

clock' = pR "clock"
clock pt = p "clock" $ clock' pt

:}

:{

genEventId :: IO String
genEventId = do
  let chars :: String
      chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  sequence
    [ do
        idx <- randomRIO (0, length chars - 1)
        pure (head (Prelude.drop idx chars))
    | _ <- [1..9]
    ]

createMsgPack :: Arc -> String -> IO Object
createMsgPack arc replyType = do
  events <- (streamActivePt' tidal arc)
  wrappedEvents <-
    traverse (\event -> (\k -> (ObjectStr (T.pack k), event)) <$> genEventId) events
  let eventsObj = ObjectMap (V.fromList wrappedEvents)
  pure $
    ObjectMap $
      V.fromList
        [ (ObjectStr "type",   ObjectStr $ T.pack(replyType))
        , (ObjectStr "events", eventsObj)
        ]

socketPath :: FilePath
socketPath = "/tmp/tidal.sock"

sendMessage :: IO Object -> IO ()
sendMessage ioEvents = do
  events <- ioEvents
  let msg = BL.toStrict (Data.MessagePack.pack events)
  sock <- socket AF_UNIX S.Stream defaultProtocol
  connect sock (SockAddrUnix socketPath)
  NSB.sendAll sock msg
  close sock

:}
