module LambdaHeights.Types.MainMenuState where

import           Data.Matrix
import           LambdaHeights.GUI.Table.Types
import           Linear.V2

newtype State = State {
  menu :: Table
}

newState :: State
newState = State {menu = Table (fromLists [["play"], ["replay"], ["exit"]]) (V2 1 1)}