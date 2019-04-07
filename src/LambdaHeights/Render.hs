module LambdaHeights.Render where

import           Foreign.C.Types

import           LambdaHeights.Types

import qualified Data.Text                     as T

import qualified LambdaHeights.Screen            as Screen
import qualified LambdaHeights.UserInterface     as UI

import qualified SDL
import qualified SDL.Font                      as SDLF

renderButton
  :: SDL.Renderer -> WindowSize -> Screen.Screen -> SDLF.Font -> SDLF.Color -> UI.Button -> IO ()
renderButton renderer windowSize screen font color button = do
  (w, h) <- SDLF.size font $ T.pack $ UI.text button
  let SDL.V2 x y = Screen.toWindowPosition screen windowSize (UI.position button)
  let deltaX     = round (realToFrac w / 2 :: Float)
  let deltaY     = round (realToFrac h / 2 :: Float)
  renderText renderer font (SDL.V2 (x - deltaX) (y - deltaY)) color $ UI.text button

renderText :: SDL.Renderer -> SDLF.Font -> SDL.V2 CInt -> SDLF.Color -> String -> IO ()
renderText renderer font position color text = do
  surface <- SDLF.blended font color (T.pack text)
  texture <- SDL.createTextureFromSurface renderer surface
  SDL.freeSurface surface
  textureInfo <- SDL.queryTexture texture
  let w = SDL.textureWidth textureInfo
  let h = SDL.textureHeight textureInfo
  SDL.copy renderer texture Nothing (Just $ SDL.Rectangle (SDL.P position) (SDL.V2 w h))
  SDL.destroyTexture texture
