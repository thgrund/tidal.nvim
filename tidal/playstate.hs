import Sound.Tidal.Pattern 
import Sound.Tidal.Params (pR) 
import Sound.Tidal.Stream.Types
import GHC.Real (denominator, numerator)

import qualified Data.Map as Map
import Control.Concurrent.MVar (readMVar)
import Data.Maybe (fromMaybe)
import Data.List (intercalate, sortOn)

:{

hasClockId :: Event ValueMap -> Bool
hasClockId (Event _ _ _ eventMap) =
  case Data.Map.lookup "_id_" eventMap of
    Just (VS "clock") -> True
    _                 -> False


showId eventMap = case Data.Map.lookup "_id_" eventMap of
  Just (VS idVal) -> idVal
  _ -> "none" 

showS eventMap = case Data.Map.lookup "s" eventMap of
  Just (VS soundVal) -> soundVal
  _ -> "none" 

showNote eventMap = case Data.Map.lookup "note" eventMap of
  Just (VN noteVal) -> unNote noteVal 
  _ ->0.0 


prettyRat' r = ((show $ numerator r), (show $ denominator r))

-- map (\ ctx -> (fst $ fst ctx) (snd $ fst ctx) ) 


-- createEventMsgPackObjects  :: ( Show a1 ) => EventF (ArcF Rational) (Map.Map String Value) -> a1 -> [String]
-- createEventMsgPackObjects (Event _ (Just (Arc ws we)) a@(Arc ps pe) e) contextPositions=
--   [showId e, show (transformCtx contextPositions), fst start, snd start, fst stop, snd stop, fst note, snd note, showS e]
--   where
--     start = prettyRat' ws
--     stop = prettyRat' we
--     note = prettyRat' (showNote e) 
--     transformCtx x = map (\ ctx -> (fst $ fst ctx) (snd $ fst ctx) ) x

createEventMsgPackObjects
  :: EventF (ArcF Rational) (Map.Map String Value)
  -> [((Int, Int), (Int, Int))]
  -> [String]
createEventMsgPackObjects (Event _ (Just (Arc ws we)) _ e) contextPositions =
  [ showId e
  , show (transformCtx contextPositions)
  , fst start, snd start
  , fst stop,  snd stop
  , fst note,  snd note
  , showS e
  ]
  where
    start = prettyRat' ws
    stop  = prettyRat' we
    note  = prettyRat' ( toRational (showNote e))
    transformCtx :: [((Int, Int), (Int, Int))] -> [(Int, Int)]
    transformCtx = map fst

-- Show context of an event
-- showEventAll' e = show (context e) ++ uncurry (++) (showEvent' e)
--createAllEventMsgPackObjects e = map (\ ctx -> createEventMsgPackObjects e (fst $ fst ctx) (snd $ fst ctx) ) (contextPosition $ context e)
createAllEventMsgPackObjects e = createEventMsgPackObjects e (contextPosition $ context e) 

-- Show everything, including event context
-- showAll' :: [Event ValueMap] -> String

-- sanitizeAll es = concatMap createAllEventMsgPackObjects $ sortOn part $ filter (not . hasClockId) es
sanitizeAll :: [Event ValueMap] -> [[String]]
sanitizeAll es =
  map createAllEventMsgPackObjects $
    sortOn part $
      filter (not . hasClockId) es

streamActivePt s arc = do
  pMap <- readMVar (sPMapMV s)
  cMap <- readMVar (sStateMV s)
  events <- ioEvents cMap pMap 
 --  putStrLn (intercalate "," (sanitizeAll events))
  putStrLn (intercalate "\n" (map (intercalate ",") (sanitizeAll events)))
  where
    showKV cMap (k, x) =  (query $ psPattern x) (State (arc) cMap)
    ioEvents cMap pMap = return (concatMap (showKV cMap) $ Map.toList pMap)

clock' = pR "clock"
clock pt = p "clock" $ clock' pt

:}

