module D3.Layouts.Simulation where

import D3.FFI
import Prelude

import D3.Attributes.Instances (Attribute(..), Label, unbox)
import D3.Data.Types (D3Simulation_, Datum_, PointXY)
import D3.Node (D3_Link, NodeID)
import D3.Simulation.Config (ChainableF(..), D3ForceHandle_, SimulationConfig_, defaultConfigSimulation)
import Data.Array (elem, foldl, intercalate, uncons, (:))
import Data.List (List)
import Data.Map (Map, empty, fromFoldable, insert, lookup, toUnfoldable, update) as M
import Data.Map.Internal (keys) as M
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, wrap, unwrap)
import Data.Tuple (Tuple(..))

data ForceStatus = ForceActive | ForceDisabled
derive instance eqForceStatus :: Eq ForceStatus
instance showForceStatus :: Show ForceStatus where
  show ForceActive = "active"
  show ForceDisabled = "inactive"

toggleForceStatus :: ForceStatus -> ForceStatus
toggleForceStatus =
  case _ of
    ForceActive   -> ForceDisabled
    ForceDisabled -> ForceActive

getLabel :: Force -> Label
getLabel (Force l _ _ _ _) = l

getHandle :: Force -> D3ForceHandle_
getHandle (Force l s t cs h_) = h_


-- TODO we won't export the constructor here when we close exports
data Force = Force Label ForceStatus ForceType (Array ChainableF) D3ForceHandle_

createForce :: Label -> ForceType -> Array ChainableF -> Force
createForce l t cs = Force l ForceDisabled t cs (createForce_ t)

disableForce :: Force -> Force
disableForce (Force l _ t cs h) = Force l ForceDisabled t cs h

enableForce :: Force -> Force
enableForce (Force l _ t cs h) = Force l ForceActive t cs h
-- TODO but in fact when we toggle "Active" maybe we want to get a handle from D3 for it if it didn't have one? 

toggleForce :: Force -> Force
toggleForce (Force l s t cs h_) = Force l (toggleForceStatus s) t cs h_
-- TODO but in fact when we toggle "Active" maybe we want to get a handle from D3 for it if it didn't have one? 

newtype SimulationManager = SimulationManager {
    simulation :: D3Simulation_
  , config     :: SimulationConfig_
  , forces     :: M.Map Label Force
}
derive instance Newtype SimulationManager _

instance Show Force where
  show (Force label status t cs h) = "Force: " <> label <> " " <> show status 

showForces :: SimulationManager -> String
showForces (SimulationManager sim) = do
  let forceTuples = M.toUnfoldable sim.forces
      showTuple (Tuple label force) = show label <> " " <> show force
  intercalate "\n" $ showTuple <$> forceTuples

createSimulationManager :: SimulationManager 
createSimulationManager = wrap { 
    simulation: initSimulation_ defaultConfigSimulation  
  , config: defaultConfigSimulation
  , forces: M.empty
}

setAlpha :: Number ->  SimulationManager -> SimulationManager
setAlpha v (SimulationManager sim) = do
  let _ = setAlpha_ sim.simulation v
  wrap sim { config { alpha = v }}

setAlphaTarget :: Number ->  SimulationManager -> SimulationManager
setAlphaTarget v (SimulationManager sim) = do
  let _ = setAlphaTarget_ sim.simulation v
  wrap sim { config { alphaTarget = v }}

setAlphaMin :: Number ->  SimulationManager -> SimulationManager
setAlphaMin v (SimulationManager sim) = do
  let _ = setAlphaMin_ sim.simulation v
  wrap sim { config { alphaMin = v }}

setAlphaDecay :: Number ->  SimulationManager -> SimulationManager
setAlphaDecay v (SimulationManager sim) = do
  let _ = setAlphaDecay_ sim.simulation v
  wrap sim { config { alphaDecay = v }}

setVelocityDecay :: Number ->  SimulationManager -> SimulationManager
setVelocityDecay v (SimulationManager sim) = do
  let _ = setVelocityDecay_ sim.simulation v
  wrap sim { config { velocityDecay = v }}

setRunning :: Boolean ->  SimulationManager -> SimulationManager
setRunning true = start
setRunning false = stop


start :: SimulationManager -> SimulationManager
start (SimulationManager sim) = do
  let _ = startSimulation_  sim.simulation
      _ = setAlpha_ sim.simulation 1.0
  wrap sim { config { running = true } }

stop :: SimulationManager -> SimulationManager
stop (SimulationManager sim) = do
  let _ = stopSimulation_  sim.simulation
  wrap sim { config { running = false } }

loadForces :: Array Force -> SimulationManager -> SimulationManager
loadForces forces sim = addForces forces $ removeAllForces sim

addForces :: Array Force -> SimulationManager -> SimulationManager
addForces fs sim = 
  case uncons fs of
    Just f -> addForces f.tail (sim `addForce` f.head)
    Nothing -> sim

addForce :: SimulationManager -> Force -> SimulationManager
addForce (SimulationManager sim) force@(Force l s t attrs h_) = do
  -- addForce and label in D3 first
  let _ = (\a -> setForceAttr h_ (unwrap a)) <$> attrs
      s' = if s == ForceActive
           then putForceInSimulation sim.simulation force
           else sim.simulation -- if the force isn't active then we just keep it in map, with label is key
  wrap sim { forces = M.insert l force sim.forces, simulation = s'  }

putForceInSimulation :: D3Simulation_ -> Force -> D3Simulation_
putForceInSimulation simulation (Force l s t attrs h_) = do
  case t of
    ForceManyBody -> putForceInSimulation_ simulation l h_
    ForceCenter   -> putForceInSimulation_ simulation l h_
    ForceCollide  -> putForceInSimulation_ simulation l h_
    ForceX        -> putForceInSimulation_ simulation l h_
    ForceY        -> putForceInSimulation_ simulation l h_
    ForceRadial   -> putForceInSimulation_ simulation l h_

    (ForceLink _) -> putForceInSimulation_ simulation l h_

    (ForceFixPositionXY f) -> applyFixForceInSimulationXY_ simulation l f
    (ForceFixPositionX f)  -> applyFixForceInSimulationX_ simulation l f
    (ForceFixPositionY f)  -> applyFixForceInSimulationY_ simulation l f

    CustomForce   -> putForceInSimulation_ simulation l h_ -- TODO not implemented or even designed yet



enableByLabelMany :: Array Label -> SimulationManager -> SimulationManager
enableByLabelMany labels (SimulationManager sim) = do
  let updatedForces = (enableByLabels sim.simulation labels) <$> sim.forces
  wrap sim { forces = updatedForces }

disableByLabelMany :: Array Label -> SimulationManager -> SimulationManager
disableByLabelMany labels (SimulationManager sim) = do
  let updatedForces = (disableByLabels sim.simulation labels) <$> sim.forces
  wrap sim { forces = updatedForces }

removeAllForces :: SimulationManager -> SimulationManager
removeAllForces (SimulationManager sim) = do
  let _ = (setAsNullForceInSimulation_ sim.simulation) <$> (M.keys sim.forces)
  wrap sim { forces = (M.empty :: M.Map Label Force) }

disableByLabels :: D3Simulation_ -> Array Label -> Force -> Force
disableByLabels simulation labels force@(Force label _ t cs h_) =
  if label `elem` labels
  then do
    let _ = setAsNullForceInSimulation_ simulation label
    Force label ForceDisabled t cs h_
  else force

enableByLabels :: D3Simulation_ -> Array Label -> Force -> Force
enableByLabels simulation labels force@(Force label _ t cs h_) = 
  if label `elem` labels
  then do
    let _ = putForceInSimulation_ simulation label h_
    Force label ForceActive t cs h_
  else force

data ForceType = 
    ForceManyBody                                  -- strength, theta, distanceMax, distanceMin
  | ForceCenter                                    -- strength, x, y
  | ForceCollide                                   -- strength, radius, iterations
  | ForceX                                         -- strength, x
  | ForceY                                         -- strength, y
  | ForceRadial                                    -- strength, radius, x, y
  | ForceLink (forall r. Array (D3_Link NodeID r)) -- strength, id, distance, iterations, links
  | ForceFixPositionXY (Datum_ -> PointXY) -- function is static, provided to constructor
  | ForceFixPositionX  (Datum_ -> Number)
  | ForceFixPositionY  (Datum_ -> Number)
                                                   -- TODO need something to hold extra custom force config, perhaps?
  | CustomForce                                    -- ???

instance Show ForceType where
  show ForceManyBody           = "ForceManyBody"
  show ForceCenter             = "ForceCenter"
  show ForceCollide            = "ForceCollide"
  show ForceX                  = "ForceX"
  show ForceY                  = "ForceY"
  show ForceRadial             = "ForceRadial"
  show (ForceFixPositionXY xy) = "ForceFixPositionXY"
  show (ForceFixPositionX x)   = "ForceFixPositionX"
  show (ForceFixPositionY y)   = "ForceFixPositionY"
  show (ForceLink _)           = "ForceLink"
  show CustomForce             = "CustomForce"

showSimulationRunning :: SimulationManager -> String
showSimulationRunning (SimulationManager s) =
  if s.config.running
  then "Running"
  else "Paused"

forceDescription :: ForceType -> String
forceDescription = case _ of
  ForceManyBody -> 

    """The many-body (or n-body) force applies mutually amongst all nodes. It can
    be used to simulate gravity (attraction) if the strength is positive, or
    electrostatic charge (repulsion) if the strength is negative."""
      
  ForceCenter   ->
    
    """The centering force translates nodes uniformly so that the mean position
    of all nodes (the center of mass if all nodes have equal weight) is at the
    given position ⟨x,y⟩. """
  
  ForceCollide  ->

    """The collision force treats nodes as circles with a given radius, rather
    than points, and prevents nodes from overlapping."""

  ForceX        ->

    """The x-positioning force pushes nodes towards a desired position along the
    horizontal with a configurable strength."""

  ForceY        ->

    """The y-positioning force pushes nodes towards a desired position along the
    vertical with a configurable strength."""

  ForceRadial   ->

    """The radial force pushes nodes towards the closest point on a given circle."""

  (ForceFixPositionXY xy) ->

    """This \"force\" is really an over-ride for the force simulation, fixing the node at a particular point"""

  (ForceFixPositionX x) ->

    """This \"force\" is really an over-ride for the force simulation, fixing the node at a particular X dimension"""

  (ForceFixPositionY y) ->

    """This \"force\" is really an over-ride for the force simulation, fixing the node at a particular Y dimension"""

  (ForceLink _) ->

    """The link force pushes linked nodes together or apart according to the
    desired link distance. The strength of the force is proportional to the
    difference between the linked nodes’ distance and the target distance,
    similar to a spring force."""

  CustomForce   -> ""


-- TODO this needs to move to the D3 interpreter, with some parallel impls for String, Meta etc
createForce_ :: ForceType -> D3ForceHandle_
createForce_ = case _ of
  ForceManyBody             -> forceMany_      unit 
  ForceCenter               -> forceCenter_    unit
  ForceCollide              -> forceCollideFn_ unit
  ForceX                    -> forceX_         unit
  ForceY                    -> forceY_         unit
  ForceRadial               -> forceRadial_    unit

  (ForceLink links)         -> forceLink_      links
  (CustomForce)             -> forceCustom_    unit
  -- NB there is actually no "force", in D3 terms, behind the fixed "forces", hence the dummy handle that is returned
  (ForceFixPositionXY xy)   -> dummyForceHandle_ 
  (ForceFixPositionX x)     -> dummyForceHandle_
  (ForceFixPositionY y)     -> dummyForceHandle_

-- TODO at present there is no type checking on what forces have which attrs settable, see comment above
setForceAttr :: D3ForceHandle_ -> Attribute -> D3ForceHandle_
setForceAttr force_ (ToAttribute label attr) = do
  case label of
    "radius"      -> setForceRadius_      force_ (unbox attr) -- valid 
    "strength"    -> setForceStrength_    force_ (unbox attr)
    -- "cx"          -> setForceCx_          force_ (unbox attr)
    -- "cy"          -> setForceCy_          force_ (unbox attr)
    "theta"       -> setForceTheta_       force_ (unbox attr)
    "distanceMin" -> setForceDistanceMin_ force_ (unbox attr)
    "distanceMax" -> setForceDistanceMax_ force_ (unbox attr)
    "iterations"  -> setForceIterations_  force_ (unbox attr)
    "x"           -> setForceX_           force_ (unbox attr)
    "y"           -> setForceY_           force_ (unbox attr)
    "distance"    -> setForceDistance_    force_ (unbox attr)
    _ -> force_ -- no other force attributes accepted


  
