{-# LANGUAGE DeriveGeneric #-}

module LambdaTower.Ingame.Events where

import Codec.Serialise

import GHC.Generics

data Direction = MoveLeft
               | MoveRight
               deriving (Generic)

instance Serialise Direction

data PlayerEvent = PlayerMoved Direction Bool
                 | PlayerJumped
                 deriving (Generic)

instance Serialise PlayerEvent