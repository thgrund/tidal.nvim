:set -fno-warn-orphans -Wno-type-defaults -XMultiParamTypeClasses -XOverloadedStrings
:set prompt ""
:set -package tidal
:set -package tidal-core

-- Import all the boot functions and aliases.
import Sound.Tidal.Boot

default (Rational, Integer, Double, Pattern String)

-- Create a Tidal Stream with the default settings.
-- To customize these settings, use 'mkTidalWith' instead
-- tidalInst <- mkTidal

-- tidalInst <- mkTidalWith [(superdirtTarget { oLatency = 0.01 }, [superdirtShape])] (defaultConfig {cFrameTimespan = 1/50, cProcessAhead = 1/20})
-- let editorTarget = Target {oName = "editor", oAddress = "127.0.0.1", oPort = 6013, oLatency = 0.07, oSchedule = Pre BundleStamp, oWindow = Nothing, oHandshake = False, oBusPort = Nothing }

--let editorTarget = Target {oName = "editor", oAddress = "127.0.0.1", oPort = 6013, oLatency = 0.03, oSchedule = Live, oWindow = Nothing, oHandshake = False, oBusPort = Nothing }
--let editorShape = OSCContext "/editor/highlights"

let clockShape = OSC "/ping" $ Named {requiredArgs = ["clock"]}
let clockTarget = Target {oName = "clock", oAddress = "127.0.0.1", oPort = 6013, oLatency = ((3/10)), oSchedule = Live, oWindow = Nothing, oHandshake = False, oBusPort = Nothing }

--tidalInst <- mkTidalWith [(superdirtTarget { oLatency = -0.02 }, [superdirtShape]), (editorTarget, [editorShape])] (defaultConfig {cFrameTimespan = 1/50, cProcessAhead = 1/20})
tidalInst <- mkTidalWith [(superdirtTarget { oLatency = -0.02 }, [superdirtShape]), (clockTarget, [clockShape])] (defaultConfig {cFrameTimespan = 1/50, cProcessAhead = 1/20})

-- This orphan instance makes the boot aliases work!
-- It has to go after you define 'tidalInst'.
instance Tidally where tidal = tidalInst

:set prompt "tidal> "
:set prompt-cont ""
