module LambdaTower.Replay.Render where

import LambdaTower.Graphics
import LambdaTower.Loop

import qualified LambdaTower.Ingame.Render as Ingame
import qualified LambdaTower.Types.ReplayState as State

renderReplay :: Graphics -> Ingame.RenderConfig -> Renderer IO State.ReplayState
renderReplay graphics config timer state =
  Ingame.defaultRender graphics config timer $ State.state state