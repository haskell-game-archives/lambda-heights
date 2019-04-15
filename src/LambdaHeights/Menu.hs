module LambdaHeights.Menu
  (
 -- * Input handling
    keyInput
 -- * Updating
  , ToResult
  , update
 -- * Rendering
  , RenderConfig(..)
  , defaultConfig
  , deleteConfig
  , render
  , renderNoClear
  )
where

import           Data.Maybe
import           Data.Word
import qualified LambdaHeights.Render          as Render
import           LambdaHeights.RenderContext
import qualified LambdaHeights.Scale           as Scale
import           LambdaHeights.Types.KeyEvents
import qualified LambdaHeights.Types.Label     as UI
import qualified LambdaHeights.Types.MenuState as UI
import qualified LambdaHeights.Types.Screen    as Screen
import qualified LambdaHeights.Types.Timer     as Timer
import qualified SDL
import qualified SDL.Font                      as SDLF

-- | Polls pending events and converts them to key events.
keyInput :: IO [KeyEvent]
keyInput = mapMaybe eventToKeyEvent <$> SDL.pollEvents

eventToKeyEvent :: SDL.Event -> Maybe KeyEvent
eventToKeyEvent event = case SDL.eventPayload event of
  SDL.KeyboardEvent keyEvent ->
    let code   = SDL.keysymKeycode (SDL.keyboardEventKeysym keyEvent)
        motion = SDL.keyboardEventKeyMotion keyEvent
    in  keyToKeyEvent code motion
  _ -> Nothing

keyToKeyEvent :: SDL.Keycode -> SDL.InputMotion -> Maybe KeyEvent
keyToKeyEvent SDL.KeycodeReturn SDL.Pressed = Just Enter
keyToKeyEvent SDL.KeycodeW      SDL.Pressed = Just Up
keyToKeyEvent SDL.KeycodeUp     SDL.Pressed = Just Up
keyToKeyEvent SDL.KeycodeS      SDL.Pressed = Just Down
keyToKeyEvent SDL.KeycodeDown   SDL.Pressed = Just Down
keyToKeyEvent _                 _           = Nothing


-- Update the menu.

type ToResult a = UI.Label -> a

-- | Applies key events to the current menu.
update :: ToResult a -> Timer.LoopTimer -> [KeyEvent] -> UI.State -> Either a UI.State
update toResult _ events menu =
  let list = UI.applyEvents menu events
  in  if UI.confirmed list then Left $ toResult $ UI.selectedItem list else Right list

data RenderConfig = RenderConfig {
  font              :: SDLF.Font,
  backgroundColor   :: SDL.V4 Word8,
  textColor         :: SDL.V4 Word8,
  selectedTextColor :: SDL.V4 Word8
}

defaultConfig :: IO RenderConfig
defaultConfig = do
  loadedFont <- SDLF.load "HighSchoolUSASans.ttf" 28
  return $ RenderConfig
    { font              = loadedFont
    , backgroundColor   = SDL.V4 30 30 30 255
    , textColor         = SDL.V4 255 255 255 255
    , selectedTextColor = SDL.V4 0 191 255 255
    }

deleteConfig :: RenderConfig -> IO ()
deleteConfig = SDLF.free . font

-- | Renders the menu.
render :: RenderContext -> RenderConfig -> Timer.LoopTimer -> UI.State -> IO ()
render (window, renderer) config timer menu = do
  SDL.rendererDrawColor renderer SDL.$= backgroundColor config
  SDL.clear renderer
  renderNoClear (window, renderer) config timer menu

-- | Renders the menu without clearing the screen.
renderNoClear :: RenderContext -> RenderConfig -> Timer.LoopTimer -> UI.State -> IO ()
renderNoClear (window, renderer) config _ menu = do
  let screen     = Screen.newScreen
  let selectedId = UI.selected menu
  windowSize <- SDL.get $ SDL.windowSize window
  mapM_ (renderLabel renderer config windowSize screen selectedId) $ UI.labels menu
  SDL.present renderer

renderLabel
  :: SDL.Renderer -> RenderConfig -> Scale.WindowSize -> Screen.Screen -> Int -> UI.Label -> IO ()
renderLabel renderer config windowSize screen selectedId button = do
  let color = if selectedId == UI.id button then selectedTextColor config else textColor config
  Render.renderLabel renderer windowSize screen (font config) color button
