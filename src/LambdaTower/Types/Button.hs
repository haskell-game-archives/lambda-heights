module LambdaTower.Types.Button where

import           LambdaTower.Types

data Button = Button {
  id :: Int,
  text :: String,
  position :: Position
}
