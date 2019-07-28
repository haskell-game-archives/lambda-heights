{-# LANGUAGE DeriveGeneric #-}

module LambdaHeights.Types.Events where

import           Codec.Serialise
import           GHC.Generics

data Events = Events {
  control :: [ControlEvent],
  player  :: [PlayerEvent]
}

data ControlEvent = Paused
                  | Slower
                  | Faster
                  deriving (Eq)

data PlayerEvent = PlayerMoved Direction Bool
                 | PlayerJumped
                 deriving (Eq, Generic)

data Direction = MoveLeft
               | MoveRight
               deriving (Eq, Generic)

instance Serialise PlayerEvent
instance Serialise Direction
