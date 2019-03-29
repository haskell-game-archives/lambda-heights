module LambdaTower.Score.Render where

import           Data.Word

import qualified SDL
import qualified SDL.Font                      as SDLF

import           LambdaTower.Graphics
import           LambdaTower.Loop
import           LambdaTower.Types

import qualified LambdaTower.Render            as Render
import qualified LambdaTower.Screen            as Screen
import qualified LambdaTower.Types.Button      as Button
import qualified LambdaTower.Types.ButtonList  as ButtonList
import qualified LambdaTower.Types.ScoreState  as State

data RenderConfig = RenderConfig {
  font :: SDLF.Font,
  backgroundColor :: SDL.V4 Word8,
  textColor :: SDL.V4 Word8,
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

render :: Graphics -> RenderConfig -> Renderer IO State.ScoreState
render (window, renderer) config _ state = do
  SDL.rendererDrawColor renderer SDL.$= backgroundColor config
  SDL.clear renderer

  let buttonList = State.buttonList state
  let view       = ButtonList.screen buttonList
  let selectedId = ButtonList.selected buttonList
  let text       = "score: " ++ show (State.score state)

  windowSize <- SDL.get $ SDL.windowSize window
  renderButton renderer config windowSize view (-1) $ Button.Button 0 text (500, 550)
  mapM_ (renderButton renderer config windowSize view selectedId) $ ButtonList.buttons buttonList

  SDL.present renderer

renderButton :: SDL.Renderer -> RenderConfig -> WindowSize -> Screen.Screen -> Int -> Button.Button -> IO ()
renderButton renderer config windowSize screen selectedId button = do
  let color = if selectedId == Button.id button then selectedTextColor config else textColor config
  Render.renderButton renderer windowSize screen (font config) color button
