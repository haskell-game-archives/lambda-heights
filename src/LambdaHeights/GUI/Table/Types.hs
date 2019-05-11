module LambdaHeights.GUI.Table.Types where

import           Data.Matrix
import           Data.Word
import           Linear.V2
import           Linear.V4
import qualified SDL
import qualified SDL.Font    as SDLF

type Color = V4 Word8

type Location = V2 Int
type Size = V2 Int

type CellStyler a = Table -> Matrix a
type CellSizer a = Table -> Matrix a -> Matrix Size
type CellLocator = Table -> Matrix Size -> Matrix Location
type TextLocator = Table -> Matrix Size -> Matrix Location -> Matrix Location

type RenderTable a = Table -> TableView a -> IO ()
type RenderCell a = Table -> TableView a -> Location -> IO ()

type UpdateTable = [SDL.Event] -> Table -> Table

data Table = Table {
  content  :: Matrix String,
  selected :: V2 Int
}

data TableView a = TableView {
  styles        :: Matrix a,
  sizes         :: Matrix Size,
  locations     :: Matrix Location,
  textLocations :: Matrix Location
}

data TableViewGenerators a = TableViewGenerators {
  styleCells  :: CellStyler a,
  sizeCells   :: CellSizer a,
  locateCells :: CellLocator,
  locateText  :: TextLocator
}

data CellStyle = CellStyle {
  cellFont :: SDLF.Font,
  cellBg   :: Color,
  cellFg   :: Color
}

tableDimension :: Table -> V2 Int
tableDimension table = let m = content table in V2 (nrows m) (ncols m)

tableSize :: TableView a -> V2 Int
tableSize view =
  let locations'   = locations view
      sizes'       = sizes view
      maxPositions = mapPos (\(r, c) pos -> pos + getElem r c sizes') locations'
      minList      = toList locations'
      maxList      = toList maxPositions
      getX (V2 x _) = x
      getY (V2 _ y) = y
      minX = minimum $ map getX minList
      maxX = maximum $ map getX maxList
      minY = minimum $ map getY minList
      maxY = maximum $ map getY maxList
  in  V2 (maxX - minX) (maxY - minY)

cellLocations :: Table -> [Location]
cellLocations table =
  let V2 rCount cCount = tableDimension table
  in  [ V2 r c | r <- [1 .. rCount], c <- [1 .. cCount] ]
