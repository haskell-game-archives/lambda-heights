module LambdaTower.Game (
  start
) where

import Control.Concurrent.Async
import Control.Concurrent.STM.TChan

import LambdaTower.Graphics
import LambdaTower.Loop
import LambdaTower.Recorder
import LambdaTower.State

import qualified LambdaTower.Ingame.Input as I
import qualified LambdaTower.Ingame.Render as I
import qualified LambdaTower.Ingame.GameState as I
import qualified LambdaTower.Ingame.Update as I

import qualified LambdaTower.Menu.Input as M
import qualified LambdaTower.Menu.MenuState as M
import qualified LambdaTower.Menu.Render as M
import qualified LambdaTower.Menu.Update as M

defaultReplayFilePath :: String
defaultReplayFilePath = "replay.dat"

start :: IO ()
start = do
  graphics <- newGraphics "LambdaTower"
  _ <- startState graphics Menu
  deleteGraphics graphics

startState :: Graphics -> State -> IO State
startState _        Exit   = return Exit
startState graphics Menu   = startMenu graphics >>= startState graphics
startState graphics Ingame = startGame defaultReplayFilePath graphics >>= startState graphics
startState graphics Replay = startReplay defaultReplayFilePath graphics >>= startState graphics

startMenu :: Graphics -> IO State
startMenu graphics = do
  timer <- defaultTimer
  config <- M.defaultConfig

  let loop = timedLoop M.handleKeyInput M.update (M.render graphics config)
  state <- startLoop timer M.newMenuState loop

  M.deleteConfig config
  return state

startGame :: FilePath -> Graphics -> IO State
startGame replayFilePath graphics = do
  timer <- defaultTimer
  channel <- newTChanIO
  config <- I.defaultConfig

  safeDeleteFile replayFilePath
  handle <- async $ serializeFromTChanToFile replayFilePath channel

  let millis = current timer
  let loop = timedLoop I.handleKeyInput (I.updateAndWrite channel) (I.render graphics config)
  _ <- startLoop timer (I.newGameState millis) loop

  wait handle
  I.deleteConfig config
  return Menu

startReplay :: FilePath -> Graphics -> IO State
startReplay replayFilePath graphics = do
  maybeStates <- deserializeFromFile replayFilePath

  case maybeStates of
    Nothing -> return Menu
    Just [] -> return Menu
    Just events -> do
      timer <- defaultTimer
      config <- I.defaultConfig

      let millis = current timer
      let loop = timedLoop (I.dummyHandleInput ()) I.replayUpdate (I.renderReplay graphics config)
      _ <- startLoop timer (events, I.newGameState millis) loop

      I.deleteConfig config
      return Menu