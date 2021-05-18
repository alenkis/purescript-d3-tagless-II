module D3.Examples.Tree.Meta where

import D3.Node

import D3.Attributes.Sugar (classed, fill, fontFamily, fontSize, getWindowWidthHeight, radius, strokeColor, strokeOpacity, strokeWidth, text, textAnchor, transform, viewBox, x, y)
import D3.Data.Types (D3Selection_, Datum_, Element(..), TreeModel, TreeType(..))
import D3.FFI (descendants_, getLayout, hNodeHeight_, hierarchyFromJSON_, links_, runLayoutFn_, treeMinMax_, treeSetNodeSize_)
import D3.Interpreter (class D3InterpreterM, append, attach, (<+>))
import D3.Interpreter.D3 (runD3M)
import D3.Interpreter.MetaTree (D3GrammarNode)
import D3.Layouts.Hierarchical (positionXY, verticalLink)
import D3.Selection (Join(..), Keys(..), node)
import Data.Maybe (fromMaybe)
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Prelude (class Bind, Unit, bind, negate, pure, unit, ($), (*), (+), (-), (/), (<$>))
import Type.Row (type (+))
import Unsafe.Coerce (unsafeCoerce)

-- Model data types specialized with inital data
type MetaTreeNodeRow row = ( 
    name   :: String
  , symbol :: String
  , param1 :: String
  , param2 :: String 
  | row )
type MetaTreeNodeData = { | MetaTreeNodeRow () }

type MetaTreeNode     = D3TreeRow (EmbeddedData MetaTreeNodeData + ())


-- | Evaluate the tree drawing script in the "d3" monad which will render it in SVG
-- | TODO specialize runD3M so that this function isn't necessary
drawTree :: TreeModel -> Aff Unit
drawTree treeModel = liftEffect $ do
  widthHeight <- getWindowWidthHeight
  let tree = hierarchyFromJSON_ treeModel.json
  (_ :: Tuple D3Selection_ Unit) <- runD3M (treeScript widthHeight tree)
  pure unit

-- | "script" to produce the documentation-ready rendering of another script's structure
-- | (could also be the basis for graphical editor of scripts / trees)
treeScript :: forall m selection. Bind m => D3InterpreterM selection m => 
  Tuple Number Number -> MetaTreeNode -> m selection
treeScript (Tuple width height) tree = do
  let 
    -- configure dimensions
    columns                    = 3.0  -- 3 columns, set in the grid CSS in index.html
    gap                        = 10.0 -- 10px set in the grid CSS in index.html
    svgWH                      = { width : ((width - ((columns - 1.0) * gap)) / columns)
                                 , height: height / 2.0 } -- 2 rows
    numberOfLevels             = (hNodeHeight_ tree) + 1.0
    spacing                    = { interChild: 120.0, interLevel: svgWH.height / numberOfLevels}
    layoutFn                   = (getLayout TidyTree) `treeSetNodeSize_` [ spacing.interChild, spacing.interLevel ]
    laidOutRoot_               = layoutFn `runLayoutFn_` tree
    { xMin, xMax, yMin, yMax } = treeMinMax_ laidOutRoot_
    xExtent                    = xMax - xMin -- ie if tree spans from -50 to 200, it's extent is 250
    yExtent                    = yMax - yMin -- ie if tree spans from -50 to 200, it's extent is 250


  -- "script"
  root       <- attach "div#meta"                           
  svg        <- root `append` (node Svg  [ viewBox (-svgWH.width / 2.0) (-20.0) svgWH.width svgWH.height ] )          
  container  <- svg  `append` (node Group [ fontFamily      "sans-serif"
                                          , fontSize        18.0
                                          ])
  links      <- container `append` (node Group [ classed "links"])
  nodes      <- container `append` (node Group [ classed "nodes"])

  theLinks_  <- links <+> Join {
      element   : Path
    , key       : UseDatumAsKey
    , "data"    : links_ tree
    , behaviour : [ strokeWidth   1.5
                  , strokeColor   "black"
                  , strokeOpacity 0.4
                  , fill          "none"
                  , verticalLink
                  ]
  }

  nodeJoin_  <- nodes <+> Join {
      element   : Group
    , key       : UseDatumAsKey
    , "data"    : descendants_ <$> tree
    -- there could be other stylistic stuff here but the transform is key structuring component
    , behaviour : [ transform [ positionXY ] ]
  }

  theNodes <- nodeJoin_ `append` 
                (node Circle  [ fill         "blue"
                              , radius       20.0
                              , strokeColor "white"
                              , strokeWidth 3.0
                              ])

  labelsWhite <- nodeJoin_ `append`
                (node Text  [ x          0.0
                            , y          3.0
                            , textAnchor "middle"
                            , text       symbol
                            , fill       "white"
                            ])
                            
  labelsGray <- nodeJoin_ `append`
                (node Text  [ x          22.0
                            , y          3.0
                            , textAnchor "start"
                            , text       param1
                            , fill       "gray"
                            ])
                            
  pure svg



-- | Coercion function to recover the "extra" data that lives within the generic structure that was given to D3, 
-- | it's an unsafeCoerce but the types give some protection
symbol :: Datum_ -> String
symbol d = node."data".symbol
  where node = unsafeCoerce d

param1 :: Datum_ -> String
param1 d = node."data".param1
  where node = unsafeCoerce d

