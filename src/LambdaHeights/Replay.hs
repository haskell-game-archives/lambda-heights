module LambdaHeights.Replay
  ( filePath,
    input,
    update,
    render,
  )
where

import ComposeEngine.RenderContext
import qualified ComposeEngine.Types.Loop as Loop
import qualified ComposeEngine.Types.Timer as Timer
import qualified Control.Monad.Reader as M
import qualified Control.Monad.State as M
import Data.Time
import qualified LambdaHeights.Play as Play
import LambdaHeights.Render
import LambdaHeights.Scale
import qualified LambdaHeights.Types.Events as Events
import qualified LambdaHeights.Types.PlayState as Play
import qualified LambdaHeights.Types.ReplayState as Replay
import Linear.V4

filePath :: UTCTime -> String
filePath time = "replays/" ++ formatTime defaultTimeLocale "%_Y%m%d%H%M%S" time

input :: IO [Events.ControlEvent]
input = Events.control <$> Play.keyInput

update :: Loop.Update Replay.State Replay.Result [Events.ControlEvent]
update events = do
  timer <- Loop.getUpdateTimer
  state <- Loop.getUpdateState
  if endReached state
    then Loop.putUpdateResult $ Replay.Result Play.Finished state
    else do
      updateSpeed events
      updateTimer
      let repEvents : repEventList = Replay.events state
      let playUpdate = Play.update $ Events.Events events repEvents
      let playState = (timer, Right $ Replay.playState state)
      let (_, updated) = M.execState playUpdate playState
      case updated of
        Left playResult -> do
          let state' = Replay.State (Play.state playResult) repEventList
          let result = Replay.Result (Play.reason playResult) state'
          Loop.putUpdateResult result
        Right playState' -> Loop.putUpdateState $ Replay.State playState' repEventList

updateSpeed :: [Events.ControlEvent] -> Loop.UpdateState Replay.State Replay.Result ()
updateSpeed events = do
  timer <- Loop.getUpdateTimer
  let rate = Timer.rate timer
  M.when (elem Events.Faster events && rate > 1) $ Loop.putUpdateTimer $ timer {Timer.rate = rate - 1}
  M.when (elem Events.Slower events && rate < 25) $ Loop.putUpdateTimer $ timer {Timer.rate = rate + 1}

updateTimer :: Loop.UpdateState Replay.State Replay.Result ()
updateTimer = do
  timer <- Loop.getUpdateTimer
  state <- Loop.getUpdateState
  let remainingFrames = length $ Replay.events state
  let go n
        | n < 200 && Timer.rate timer < 14 = timer {Timer.rate = 14}
        | otherwise = timer
  Loop.putUpdateTimer $ go remainingFrames

endReached :: Replay.State -> Bool
endReached = null . Replay.events

render :: (M.MonadIO m) => RenderContext -> Play.RenderConfig -> Loop.Render m Replay.State
render ctx config = do
  timer <- Loop.askRenderTimer
  state <- Loop.askRenderState
  M.runReaderT (Play.render ctx config) (timer, Replay.playState state)
  let remainingFrames = length $ Replay.events state
  M.when (remainingFrames <= 50) $ do
    let a = flipRange (normalize (0, 50) (realToFrac remainingFrames)) * 255 :: Float
    renderOverlay ctx $ V4 0 0 0 $ truncate a
