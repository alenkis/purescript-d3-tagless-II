module D3.Examples.Spago.Draw where

import Control.Monad.State (class MonadState)
import D3.Attributes.Sugar (classed, cursor, fill, height, onMouseEvent, radius, remove, strokeColor, text, textAnchor, transform', viewBox, width, x, x1, x2, y, y1, y2)
import D3.Data.Tree (TreeLayout(..))
import D3.Data.Types (D3Selection_, D3Simulation_, Element(..), MouseEvent(..))
import D3.Examples.Spago.Files (SpagoGraphLinkID)
import D3.Examples.Spago.Model (SpagoSimNode, cancelSpotlight_, datum_, link_, toggleSpotlight, tree_datum_)
import D3.Examples.Spago.Unsafe (spagoLinkKeyFunction, spagoNodeKeyFunction)
import D3.Layouts.Hierarchical (horizontalLink', radialLink, verticalLink)
import D3.Selection (Behavior(..), ChainableS, DragBehavior(..), Join(..), node, node_)
import D3.Simulation.Types (D3SimulationState_, Step(..))
import D3.Zoom (ScaleExtent(..), ZoomExtent(..))
import D3Tagless.Capabilities (class SelectionM, class SimulationM, addSelection, addTickFunction, attach, getSelection, modifySelection, on, setNodesAndLinks, simulationHandle)
import D3Tagless.Capabilities as D3
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Debug (trace)
import Effect.Class (class MonadEffect, liftEffect)
import Prelude (class Bind, Unit, bind, discard, negate, pure, unit, ($), (/), (<<<))
import Utility (getWindowWidthHeight)

-- for this (family of) visualization(s) the position updating for links and nodes is always the same
nodeTick :: Array ChainableS
nodeTick = [ transform' datum_.translateNode ]

linkTick :: Array ChainableS
linkTick = [ x1 (_.x <<< link_.source)
           , y1 (_.y <<< link_.source)
           , x2 (_.x <<< link_.target)
           , y2 (_.y <<< link_.target)
           ]

-- TODO this is a problem once extracted from "script", leads to undefined in D3.js
enterLinks :: forall t339. Array t339
enterLinks = [] -- [ classed link_.linkClass ] -- default invisible in CSS unless marked "visible"

enterAttrs :: D3Simulation_ -> Array ChainableS
enterAttrs simulation_ = 
  [ classed datum_.nodeClass
  , transform' datum_.translateNode
  , onMouseEvent MouseClick (\e d _ -> toggleSpotlight e simulation_ d)
  ]

updateAttrs :: forall t1. t1 -> Array ChainableS
updateAttrs _ = 
  [ classed datum_.nodeClass
  , transform' datum_.translateNode
  ]

-- | Some examples of pre-packaged attribute sets available to the app maker
circleAttrs1 :: Array ChainableS
circleAttrs1 = [ 
    radius datum_.radius
  , fill datum_.colorByGroup
]

circleAttrs2 :: Array ChainableS
circleAttrs2 = [
    radius 3.0
  , fill datum_.colorByUsage
]

labelsAttrs1 :: Array ChainableS
labelsAttrs1 = [ 
    classed "label"
  ,  x 0.2
  , y datum_.positionLabel
  , textAnchor "middle"
  , text datum_.indexAndID
]

-- TODO x and y position for label would also depend on "hasChildren", need to get "tree" data into nodes
labelsAttrsH :: Array ChainableS
labelsAttrsH = [ 
    classed "label"
  , x 4.0
  , y 2.0
  , textAnchor (tree_datum_.textAnchor Horizontal)
  , text datum_.name
]

graphAttrs :: { circle :: Array ChainableS , labels :: Array ChainableS }
graphAttrs = { 
    circle: circleAttrs1
  , labels: labelsAttrs1 
}

treeAttrs :: { circle :: Array ChainableS, labels :: Array ChainableS }
treeAttrs  = {
    circle: circleAttrs2
  , labels: labelsAttrsH
}

-- | recipe for this force layout graph
setup :: forall m selection. 
  Bind m => 
  MonadEffect m =>
  SelectionM selection m =>
  SimulationM selection m =>
  -- SpagoModel ->
  m Unit
setup = do
  (Tuple w h) <- liftEffect getWindowWidthHeight
  simulation_ <- simulationHandle -- needed for click handler to stop / start simulation
  root        <- attach "div.svg-container"
  svg         <- root D3.+ (node Svg  [ viewBox (-w / 2.1) (-h / 2.05) w h 
                                      -- , preserveAspectRatio $ AspectRatio XMid YMid Meet 
                                      , classed "overlay"
                                      , width w, height h
                                      , cursor "grab"
                                      , onMouseEvent MouseClick (\e d t -> cancelSpotlight_ simulation_) ] )
  inner    <- svg D3.+ (node_ Group)
  _        <- inner `on` Drag DefaultDrag
  -- because the zoom event is picked up by `svg` but applied to `inner` has to come after creation of `inner`
  _        <- svg `on` Zoom  {  extent : ZoomExtent { top: 0.0, left: 0.0 , bottom: h, right: w }
                                      , scale  : ScaleExtent 0.1 4.0 -- wonder if ScaleExtent ctor could be range operator `..`
                                      , name   : "spago"
                                      , target : inner
                                      }

  linksGroup  <- inner  D3.+ (node Group [ classed "links" ])
  nodesGroup  <- inner  D3.+ (node Group [ classed "nodes" ])
  
  addSelection "nodesGroup" nodesGroup
  addSelection "linksGroup" linksGroup
  pure unit

updateSimulation :: forall m row. 
  Bind m => 
  MonadEffect m =>
  MonadState { simulationState :: D3SimulationState_ | row } m =>
  SelectionM D3Selection_ m =>
  SimulationM D3Selection_ m =>
  Array SpagoSimNode ->
  Array SpagoGraphLinkID ->
  { circle :: Array ChainableS, labels :: Array ChainableS } -> 
  m Unit
updateSimulation nodes links attrs = do
  (Tuple nodes_ links_) <- setNodesAndLinks nodes links datum_.indexFunction-- this will have to do the shallow copy stuff to ensure continuity
  simulation_           <- simulationHandle
  maybeNodesGroup       <- getSelection "nodesGroup"
  maybeLinksGroup       <- getSelection "linksGroup"

  case maybeNodesGroup, maybeLinksGroup of
    (Just nodesGroup), (Just linksGroup) -> do
      let _ = trace { updateNodes: nodes_ } \_ -> unit
      -- first the nodes
      nodesSelection <- nodesGroup D3.<+> 
                        UpdateJoinWithKeyFunction 
                        Group 
                        nodes_ -- these nodes have been thru the simulation 
                        { enter : enterAttrs simulation_
                        , update: updateAttrs simulation_
                        , exit  : [ remove ] 
                        }
                        spagoNodeKeyFunction

      circle         <- nodesSelection D3.+ (node Circle attrs.circle)
      labels         <- nodesSelection D3.+ (node Text attrs.labels) 
      _              <- circle `on` Drag DefaultDrag

      addTickFunction "nodes" $ Step nodesSelection nodeTick
      addSelection "nodesSelection" nodesSelection
      -- now the links
      linksSelection <- linksGroup D3.<+> 
                  UpdateJoinWithKeyFunction
                  Line
                  links_ -- these nodes have been thru the simulation 
                  { enter: [ classed link_.linkClass, strokeColor link_.color ]
                  , update: [ classed "graphlinkSimUpdate" ]
                  , exit: [ remove ] }
                  spagoLinkKeyFunction

      addTickFunction "links" $ Step linksSelection linkTick
      addSelection "graphlinksSelection" linksSelection

      pure unit

  -- TODO throw an error? or log missing selection? or avoid the maybe in some other way
  -- maybe the { nodes, links, nodeSelection, linksSelection } could be a single piece of state?
    _, _ -> pure unit -- one or other necessary selection was not found

{-
updateGraphLinks :: forall m row. 
  Bind m => 
  MonadEffect m =>
  MonadState { simulationState :: D3SimulationState_ | row } m =>
  SelectionM D3Selection_ m =>
  SimulationM D3Selection_ m =>
  Array SpagoGraphLinkID ->
  m Unit
updateGraphLinks links = do
  (maybeLinksGroup :: Maybe D3Selection_) <- getSelection "linksGroup"
    
  case maybeLinksGroup of
    Nothing -> pure unit
    (Just linksGroup) -> do
      -- TODO the links need valid IDs too if they are to do general update pattern, probably best to actually make them when making the model
      linksSelection <- linksGroup D3.<+> 
                        UpdateJoinWithKeyFunction
                        Line
                        links
                        { enter: [ classed link_.linkClass, strokeColor link_.color ]
                        , update: [ classed "graphlinkSimUpdate" ]
                        , exit: [ remove ] }
                        spagoLinkKeyFunction

      addTickFunction "links" $ Step linksSelection linkTick
      addSelection "graphlinksSelection" linksSelection
      _ <- setLinks links datum_.indexFunction -- NB this is the model-defined way of getting the index function for the NodeID -> object reference swizzling that D3 does when you set the links
      pure unit

  pure unit
  
updateGraphLinks' :: forall m row. 
  Bind m => 
  MonadEffect m =>
  MonadState { simulationState :: D3SimulationState_ | row } m =>
  SelectionM D3Selection_ m =>
  SimulationM D3Selection_ m =>
  Array SpagoGraphLinkID ->
  m Unit
updateGraphLinks' links = do
  (maybeLinksGroup :: Maybe D3Selection_) <- getSelection "linksGroup"
    
  case maybeLinksGroup of
    Nothing -> pure unit
    (Just linksGroup) -> do
      linksSelection <- linksGroup D3.<+> 
                        UpdateJoinWithKeyFunction
                        Line
                        links
                        { enter: [ classed link_.linkClass, strokeColor link_.color ]
                        , update: [ classed "graphlinkUpdate" ]
                        , exit: [ remove ] }
                        spagoLinkKeyFunction

      addTickFunction "links" $ Step linksSelection linkTick
      addSelection "graphlinksSelection" linksSelection

  pure unit
  
updateTreeLinks :: forall m row. 
  Bind m => 
  MonadEffect m =>
  MonadState { simulationState :: D3SimulationState_ | row } m =>
  SelectionM D3Selection_ m =>
  SimulationM D3Selection_ m =>
  Array SpagoGraphLinkID ->
  TreeLayout -> 
  m Unit
updateTreeLinks links layout = do
  linksInSimulation <- setLinks links datum_.indexFunction

  let linkPath =
        case layout of
          Horizontal -> horizontalLink' -- the ' is because current library default horizontalLink flips x&y (tree examples written that way, should be changed)
          Radial     -> radialLink datum_.x datum_.y
          Vertical   -> verticalLink

  (maybeLinksGroup :: Maybe D3Selection_) <- getSelection "linksGroup"
  case maybeLinksGroup of
    Nothing -> pure unit
    (Just linksGroup) -> do
      linksSelection <- linksGroup D3.<+> 
                        UpdateJoinWithKeyFunction
                        Path
                        linksInSimulation
                        { enter: [ classed link_.linkClass, strokeColor link_.color, linkPath ]
                        , update: [ classed "treelinkUpdate" ]
                        , exit: [ remove ] }
                        spagoLinkKeyFunction
                        
      addTickFunction "links" $ Step linksSelection linkTick
      addSelection "treelinksSelection" linksSelection

  pure unit
-}
  
removeNamedSelection :: forall m row. 
  Bind m => 
  MonadEffect m =>
  MonadState { simulationState :: D3SimulationState_ | row } m =>
  SelectionM D3Selection_ m =>
  SimulationM D3Selection_ m =>
  String -> 
  m Unit
removeNamedSelection name = do
  (maybeSelection :: Maybe D3Selection_) <- getSelection name
  case maybeSelection of
    Nothing -> pure unit
    (Just selection) -> do
      modifySelection selection [ remove ]

  pure unit
  