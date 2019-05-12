module LambdaHeights.Types.ScoreState where

import           Data.Matrix
import           LambdaHeights.GUI.Table.Types
import           Linear.V2

type Score = Int

data State = State {
  score :: Score,
  menu  :: Table
}

newState :: Int -> State
newState s = State {score = s, menu = Table (fromLists [["score: " ++ show s]]) (V2 1 1)}
