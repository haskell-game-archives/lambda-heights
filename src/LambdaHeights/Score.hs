module LambdaHeights.Score
  ( update
  , render
  )
where

import qualified LambdaHeights.Menu             as Menu
import           LambdaHeights.RenderContext
import qualified LambdaHeights.Table            as Table
import qualified LambdaHeights.Types.ScoreState as Score
import qualified LambdaHeights.Types.Timer      as Timer
import           Linear.V4
import qualified SDL

update :: Timer.LoopTimer -> [SDL.Event] -> Score.State -> Either () Score.State
update _ events state =
  let updated = Menu.updateDefault (const ()) events $ Score.menu state
  in  case updated of
        Left  _    -> Left ()
        Right menu -> Right $ state { Score.menu = menu }

render :: RenderContext -> Menu.RenderConfig -> Timer.LoopTimer -> Score.State -> IO ()
render (window, renderer) config _ state = do
  SDL.rendererDrawColor renderer SDL.$= V4 0 0 0 255
  SDL.clear renderer
  view <- Table.newMenuView (Menu.font config) $ Score.menu state
  Menu.render (window, renderer) view
  SDL.present renderer
