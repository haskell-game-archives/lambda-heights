module LambdaTower.Ingame.Update (
  update,
  updateAndWrite
) where

import Control.Monad.STM
import Control.Concurrent.STM.TChan

import qualified Control.Lens as L
import qualified Control.Monad.State as M

import Data.List

import LambdaTower.Loop
import LambdaTower.Types

import qualified LambdaTower.Types.GameEvents as Events
import qualified LambdaTower.Types.GameState as State
import qualified LambdaTower.Types.Layer as Layer
import qualified LambdaTower.Types.Pattern as Pattern
import qualified LambdaTower.Types.Player as Player
import qualified LambdaTower.Types.Timer as Timer
import qualified LambdaTower.Screen as Screen

-- Factor for scrolling the screen and update the acceleration.

updateFactor :: Float
updateFactor = 1 / 128


-- Wrapper around one update to broadcast the occured events for serialization

updateAndWrite :: TChan (Maybe [Events.PlayerEvent]) -> Updater IO State.GameState State.GameResult Events.GameEvents
updateAndWrite channel timer events gameState = do
  result <- update timer events gameState
  M.liftIO $ atomically $ writeTChan channel $ Just $ Events.playerEvents events
  case result of
    Left _ -> M.liftIO $ atomically $ writeTChan channel Nothing
    Right _ -> return ()
  return result


-- Control flow over one update cycle.

update :: Updater IO State.GameState State.GameResult Events.GameEvents
update timer events state = do
  let playerEvents = Events.playerEvents events
  let time = State.time state
  let screen = State.screen state
  let layers = State.layers state
  let player = State.player state
  let motion = updateMotion playerEvents layers player $ State.motion state
  return $ updatedResult events $
    State.GameState {
      State.time = time + fromIntegral (L.view Timer.rate timer),
      State.screen = updateScreen player screen,
      State.motion = resetMotion motion,
      State.player = updatePlayer screen motion layers player,
      State.layers = updateLayers screen layers
    }

updatedResult :: Events.GameEvents -> State.GameState -> Either State.GameResult State.GameState
updatedResult events state =
  let
    dead = isDead (State.screen state) (State.player state)
    paused = elem Events.Paused $ Events.controlEvents events
  in
    if dead then Left $ State.GameResult State.Finished state
    else if paused then Left $ State.GameResult State.Pause state
    else Right state


-- Updating the view involves two steps:
-- a) Move the view upwards over time.
-- b) Ensure that the player is always visible within the view.

updateScreen :: Player.Player -> Screen.Screen -> Screen.Screen
updateScreen player = scrollScreenToPlayer player . scrollScreenOverTime

scrollScreenOverTime :: Screen.Screen -> Screen.Screen
scrollScreenOverTime screen = if height == 0 then screen else scrollScreen (updateFactor * factor) screen
  where height = Screen.bottom screen
        factor = min 400 (100 + height / 100)

scrollScreenToPlayer :: Player.Player -> Screen.Screen -> Screen.Screen
scrollScreenToPlayer player screen = if distance < 250 then scrollScreen (250 - distance) screen else screen
  where (_, y) = Player.position player
        distance = Screen.top screen - y

scrollScreen :: Float -> Screen.Screen -> Screen.Screen
scrollScreen delta screen = screen {
  Screen.top = Screen.top screen + delta,
  Screen.bottom = Screen.bottom screen + delta
}


-- Apply the player events to the motion.

updateMotion :: [Events.PlayerEvent] -> [Layer.Layer] -> Player.Player -> State.Motion -> State.Motion
updateMotion events layers player motion = motion' { State.air = inAir layers player }
  where motion' = applyPlayerEvents motion events

applyPlayerEvents :: State.Motion -> [Events.PlayerEvent] -> State.Motion
applyPlayerEvents = foldl applyPlayerEvent

applyPlayerEvent :: State.Motion -> Events.PlayerEvent -> State.Motion
applyPlayerEvent moveState (Events.PlayerMoved Events.MoveLeft b) = moveState { State.moveLeft = b }
applyPlayerEvent moveState (Events.PlayerMoved Events.MoveRight b) = moveState { State.moveRight = b }
applyPlayerEvent moveState Events.PlayerJumped = moveState { State.jump = True }

resetMotion :: State.Motion -> State.Motion
resetMotion motion = motion { State.jump = False, State.air = False }


-- Drop passed and generate new layers.

newPattern :: [Pattern.PatternEntry]
newPattern = Pattern.combine 1 [
    Pattern.leftRightPattern,
    Pattern.boostPattern,
    Pattern.stairsPattern
  ]

updateLayers :: Screen.Screen -> [Layer.Layer] -> [Layer.Layer]
updateLayers screen = fillLayers screen . dropPassedLayers screen

fillLayers :: Screen.Screen -> [Layer.Layer] -> [Layer.Layer]
fillLayers screen [] = unfoldLayers screen Layer.ground
fillLayers screen (layer:layers) = unfoldLayers screen layer ++ layers

unfoldLayers :: Screen.Screen -> Layer.Layer -> [Layer.Layer]
unfoldLayers screen = reverse . unfoldr (generateLayer generator screen)
  where generator = nextLayerByPattern newPattern

nextLayerByPattern :: [Pattern.PatternEntry] -> Layer.Layer -> Layer.Layer
nextLayerByPattern [] layer = layer
nextLayerByPattern (p:ps) layer =
  case elemIndex (Layer.entryId layer) entryIds of
    Nothing -> deriveLayer p layer
    Just i -> case (p:ps ++ [p]) !! (i + 1) of p' -> deriveLayer p' layer
  where entryIds = map Pattern.entryId (p:ps)

deriveLayer :: Pattern.PatternEntry -> Layer.Layer -> Layer.Layer
deriveLayer pattern layer = Layer.Layer layerId entryId (w, h) (x, y + d)
  where Pattern.PatternEntry entryId ((w, h), x) d = pattern
        layerId = Layer.id layer + 1
        (_, y) = Layer.position layer

generateLayer :: (Layer.Layer -> Layer.Layer) -> Screen.Screen -> Layer.Layer -> Maybe (Layer.Layer, Layer.Layer)
generateLayer generator screen layer =
  if Screen.top screen < Layer.posY layer - 500
  then Nothing
  else Just (layer, generator layer)

dropPassedLayers :: Screen.Screen -> [Layer.Layer] -> [Layer.Layer]
dropPassedLayers screen = filter $ not . passed screen

passed :: Screen.Screen -> Layer.Layer -> Bool
passed screen layer = Screen.bottom screen > Layer.posY layer


-- Updating the player involves the following steps:
-- a) Update the motion of the player.
-- b) Apply collision detection and corrections.
-- c) Update the score (highest reached layer).

updatePlayer :: Screen.Screen -> State.Motion -> [Layer.Layer] -> Player.Player -> Player.Player
updatePlayer screen motion layers =
  updateScore layers
  . collidePlayerWithLayers layers
  . bouncePlayerFromBounds screen
  . updatePlayerMotion motion

updateScore :: [Layer.Layer] -> Player.Player -> Player.Player
updateScore layers player =
  case foundLayer of
    Nothing -> player
    Just layer -> player { Player.score = max (Layer.id layer) (Player.score player) }
  where foundLayer = find (player `onTop`) layers


-- Update the motion of the player (acceleration, velocity, position).

updatePlayerMotion :: State.Motion -> Player.Player -> Player.Player
updatePlayerMotion motion player = player { Player.position = pos, Player.velocity = vel, Player.acceleration = acc }
  where acc = updateAcceleration (Player.acceleration player) (Player.velocity player) motion
        vel = updateVelocity (Player.velocity player) motion acc
        pos = applyVelocity (Player.position player) vel

updateAcceleration :: Player.Acceleration -> Player.Velocity -> State.Motion -> Player.Acceleration
updateAcceleration acc (velX, velY) motion =
  if State.air motion
  then updateAirAcceleration motion
  else updateGroundAcceleration acc (velX, velY) motion

updateGroundAcceleration :: Player.Acceleration -> Player.Velocity -> State.Motion -> Player.Acceleration
updateGroundAcceleration (accX, _) (velX, velY) motion
  | jump && fast = (accX, 320000)
  | jump = (accX, 160000)
  | left && not right = (-8000, -4000)
  | right && not left = (8000, -4000)
  | otherwise = (0, -4000)
  where left = State.moveLeft motion
        right = State.moveRight motion
        jump = State.jump motion
        vel = sqrt $ (velX ** 2) + (velY ** 2)
        fast = vel >= 750

updateAirAcceleration :: State.Motion -> Player.Acceleration
updateAirAcceleration motion
  | left && not right = (-4000, -4000)
  | right && not left = (4000, -4000)
  | otherwise = (0, -4000)
  where left = State.moveLeft motion
        right = State.moveRight motion

updateVelocity :: Player.Velocity -> State.Motion -> Player.Acceleration -> Player.Velocity
updateVelocity vel motion = applyAcceleration (decelerate motion vel)

applyAcceleration :: Player.Velocity -> Player.Acceleration -> Player.Velocity
applyAcceleration (velX, velY) (accX, accY) = (velX + accX * updateFactor, velY + accY * updateFactor)

decelerate :: State.Motion -> Player.Velocity -> Player.Velocity
decelerate motion (x, y) = if State.air motion then (x * 0.99, y) else (x * 0.925, y)

applyVelocity :: Position -> Player.Velocity -> Position
applyVelocity = applyAcceleration


-- Correct the position and velocity if it is colliding with a layer
-- or the bounds of the level.

bouncePlayerFromBounds :: Screen.Screen -> Player.Player -> Player.Player
bouncePlayerFromBounds screen player
  | outLeft = player { Player.position = (minX, posY), Player.velocity = (-velX, velY) }
  | outRight = player { Player.position = (maxX, posY), Player.velocity = (-velX, velY) }
  | otherwise = player
  where (posX, posY) = Player.position player
        (velX, velY) = Player.velocity player
        minX = Screen.left screen
        maxX = Screen.right screen
        outLeft = posX < minX && velX < 0
        outRight = posX > maxX && velX > 0

collidePlayerWithLayers :: [Layer.Layer] -> Player.Player -> Player.Player
collidePlayerWithLayers layers player =
  if falling player then
    case find (player `onTop`) layers of
      Nothing -> player
      Just layer -> resetVelocityY $ liftPlayerOnLayer layer player
  else player

liftPlayerOnLayer :: Layer.Layer -> Player.Player -> Player.Player
liftPlayerOnLayer layer player = player { Player.position = (posX, Layer.posY layer) }
  where (posX, _) = Player.position player

resetVelocityY :: Player.Player -> Player.Player
resetVelocityY player = player { Player.velocity = (velX, 0) }
  where (velX, _) = Player.velocity player

isDead :: Screen.Screen -> Player.Player -> Bool
isDead screen player = let (_, y) = Player.position player in y < Screen.bottom screen

falling :: Player.Player -> Bool
falling player = let (_, y) = Player.velocity player in y < 0

inAir :: [Layer.Layer] -> Player.Player -> Bool
inAir layers player = null $ find (player `intersecting`) layers

intersecting :: Player.Player -> Layer.Layer -> Bool
intersecting player layer = xInRect position size x && yInRect position size y
  where (x, y) = Player.position player
        position = Layer.position layer
        size = Layer.size layer

onTop :: Player.Player -> Layer.Layer -> Bool
onTop player layer = xInRect position (w, h) x && yInRect position (w, 20) y
  where (x, y) = Player.position player
        position = Layer.position layer
        (w, h) = Layer.size layer

xInRect :: Position -> Size -> Float -> Bool
xInRect (posX, _) (w, _) x = x >= posX && x <= posX + w

yInRect :: Position -> Size -> Float -> Bool
yInRect (_, posY) (_, h) y = y <= posY && y >= posY - h