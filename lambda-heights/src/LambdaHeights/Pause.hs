module LambdaHeights.Pause where

import ComposeEngine.RenderContext
import qualified ComposeEngine.Types.Loop as Loop
import qualified Control.Monad.Reader as M
import qualified LambdaHeights.Menu as Menu
import LambdaHeights.Render
import qualified LambdaHeights.Table as Table
import LambdaHeights.Types.Config
import qualified LambdaHeights.Types.PauseState as Pause
import Linear.V4
import qualified SDL

newtype RenderConfig = RenderConfig {menuConfig :: Menu.RenderConfig}

createConfig :: ConfigReader RenderConfig
createConfig = RenderConfig <$> Menu.createConfig

update :: Loop.Update (Pause.State s) Pause.ExitReason [SDL.Event]
update events = do
  state <- Loop.getUpdateState
  case Menu.updateDefault toState events (Pause.menu state) of
    Left result -> Loop.putUpdateResult result
    Right menu -> M.when (Pause.menu state /= menu) $ Loop.putUpdateState $ state {Pause.menu = menu}

toState :: Maybe String -> Pause.ExitReason
toState (Just "exit") = Pause.Exit
toState _ = Pause.Resume

render ::
  (M.MonadIO m) =>
  RenderContext ->
  RenderConfig ->
  Loop.Render m s ->
  Loop.Render m (Pause.State s)
render (window, renderer) config pausedRenderer = do
  timer <- Loop.askRenderTimer
  state <- Loop.askRenderState
  M.lift $ M.runReaderT pausedRenderer (timer, Pause.pausedState state)
  renderOverlay (window, renderer) (V4 0 0 0 100)
  renderMenu (window, renderer) config state

renderMenu :: (M.MonadIO m) => RenderContext -> RenderConfig -> Pause.State s -> m ()
renderMenu ctx config state = do
  let font = Menu.font (menuConfig config)
  Table.newMenuView font (Pause.menu state) >>= Menu.render ctx (menuConfig config)
