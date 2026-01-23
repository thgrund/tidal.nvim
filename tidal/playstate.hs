import Sound.Tidal.Pattern 
import Sound.Tidal.Params (pR) 
import Sound.Tidal.Stream.Types
import GHC.Real (denominator, numerator)

import qualified Data.Map as Map
import Control.Concurrent.MVar (readMVar)
import Data.Maybe (fromMaybe)
import Data.List (intercalate, sortOn)

:{
prettyRat' r
  -- | unit == 0 && frac > 0 = showFrac (numerator frac) (denominator frac)
  | unit == 0 && frac > 0 = (show $ numerator frac) ++ "/" ++ (show $ denominator frac)
  | otherwise = "("++ show unit ++ "," ++  (show (numerator frac))  ++ "/" ++ (show (denominator frac)) ++ ")"
  where
    unit = floor r :: Int
    frac = r - toRational unit

showEvent' (Event _ (Just (Arc ws we)) a@(Arc ps pe) e) =
  (h ++ "(" ++ prettyRat' ps ++ "<" ++ prettyRat' pe ++ ")" ++ t ++ "|", show e)
  where
    h
      | ws == ps = ""
      | otherwise = prettyRat' ws ++ "-"
    t
      | we == pe = ""
      | otherwise = "-" ++ prettyRat' we
showEvent' (Event _ Nothing a e) =
  ("~" ++ show a ++ "~|", show e)

-- Show context of an event
showEventAll' :: (Show a) => Event a -> String
showEventAll' e = show (context e) ++ uncurry (++) (showEvent' e)

-- Show everything, including event context
showAll' :: [Event ValueMap] -> String
showAll' e = intercalate "\n" $ map showEventAll' $ sortOn part $ e 

streamActivePt s arc = do
  pMap <- readMVar (sPMapMV s)
  cMap <- readMVar (sStateMV s)
  events <- ioEvents cMap pMap 
  putStrLn $ showAll' events
  where
    showKV cMap (k, x) =  (query $ psPattern x) (State (arc) cMap)
    ioEvents cMap pMap = return (concatMap (showKV cMap) $ Map.toList pMap)

clock' = pR "clock"
clock pt = p "clock" $ clock' pt

:}
