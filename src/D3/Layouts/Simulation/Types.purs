module D3.Simulation.Types where

import Prelude

import D3.Attributes.Instances (AttributeSetter, Label)
import D3.Data.Types (D3Selection_, D3Simulation_, Datum_, Index_)
import D3.FFI (D3ForceHandle_, SimulationConfig_, defaultKeyFunction_, dummyForceHandle_, initSimulation_)
import D3.Selection (ChainableS)
import Data.Array (intercalate)
import Data.Lens (Lens', Prism', _Just, lens', prism', view)
import Data.Lens.At (at)
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Lens.Record (prop)
import Data.Map as M
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.Nullable (Nullable, notNull, null)
import Data.Nullable as N
import Data.Profunctor (class Profunctor)
import Data.Profunctor.Choice (class Choice)
import Data.Profunctor.Strong (class Strong)
import Data.Tuple (Tuple(..))
import Debug (trace)
import Type.Proxy (Proxy(..))

-- representation of all that is stateful in the D3 simulation engine
-- (not generalized because we have no other examples of simulation engines ATM
-- perhaps it can become a more abstract interface in the future)
newtype D3SimulationState_ = SimState_ D3SimulationStateRecord
-- TODO uses D3Selection instead of type variable, can avoid coercing if generalized correctly
type D3SimulationStateRecord = { 
    handle_       :: D3Simulation_
  , forces        :: M.Map Label Force
  , ticks         :: M.Map Label (Step D3Selection_)

  , selections    :: { nodes :: Nullable D3Selection_, links :: Nullable D3Selection_ }
  , "data"        :: { nodes :: Array Datum_         , links :: Array Datum_ }
  , key           :: (Datum_ -> Index_)

  , alpha         :: Number
  , alphaTarget   :: Number
  , alphaMin      :: Number
  , alphaDecay    :: Number
  , velocityDecay :: Number
}

derive instance Newtype D3SimulationState_ _

-- | ========================================================================================================
-- | Lenses for the simulation state
-- | ========================================================================================================
_nullable :: forall a. Prism' (Nullable a) a
_nullable = prism' notNull N.toMaybe

_handle :: Lens' D3SimulationState_ D3Simulation_
_handle = _Newtype <<< prop (Proxy :: Proxy "handle_")

_forces :: Lens' D3SimulationState_ (M.Map Label Force)
_forces = _Newtype <<< prop (Proxy :: Proxy "forces")

_force :: String -> Lens' D3SimulationState_ (Maybe Force)
_force label = _Newtype <<< prop (Proxy :: Proxy "forces") <<< at label

_ticks :: Lens' D3SimulationState_ (M.Map Label (Step D3Selection_))
_ticks = _Newtype <<< prop (Proxy :: Proxy "ticks")

_tick :: String -> Lens' D3SimulationState_ (Maybe (Step D3Selection_))
_tick label = _Newtype <<< prop (Proxy :: Proxy "ticks") <<< at label

_selections :: Lens' D3SimulationState_ { nodes :: Nullable D3Selection_, links :: Nullable D3Selection_ }
_selections = _Newtype <<< prop (Proxy :: Proxy "selections")

_data :: Lens' D3SimulationState_ { nodes :: Array Datum_ , links :: Array Datum_ }
_data = _Newtype <<< prop (Proxy :: Proxy "data")

_nodedata :: Lens' D3SimulationState_ (Array Datum_ )
_nodedata = _data <<< prop (Proxy :: Proxy "nodes")

_linkdata :: Lens' D3SimulationState_ (Array Datum_ )
_linkdata = _data <<< prop (Proxy :: Proxy "links")

-- _nodes :: forall p. Strong p => Choice p => p D3SimulationState_ D3Selection_
_nodes :: forall p. Strong p => Choice p => p D3Selection_ D3Selection_ -> p D3SimulationState_ D3SimulationState_
_nodes = _selections <<< prop (Proxy :: Proxy "nodes") <<< _nullable

_links :: forall p. Strong p => Choice p => p D3Selection_ D3Selection_ -> p D3SimulationState_ D3SimulationState_
_links = _selections <<< prop (Proxy :: Proxy "links") <<< _nullable 

_key :: Lens' D3SimulationState_ (Datum_ -> Index_)
_key = _Newtype <<< prop (Proxy :: Proxy "key")

_alpha :: Lens' D3SimulationState_ Number
_alpha = _Newtype <<< prop (Proxy :: Proxy "alpha")

_alphaTarget :: Lens' D3SimulationState_ Number
_alphaTarget   = _Newtype <<< prop (Proxy :: Proxy "alphaTarget")

_alphaMin :: Lens' D3SimulationState_ Number
_alphaMin = _Newtype <<< prop (Proxy :: Proxy "alphaMin")

_alphaDecay :: Lens' D3SimulationState_ Number
_alphaDecay = _Newtype <<< prop (Proxy :: Proxy "alphaDecay")

_velocityDecay :: Lens' D3SimulationState_ Number
_velocityDecay = _Newtype <<< prop (Proxy :: Proxy "velocityDecay")

data SimVariable = Alpha Number | AlphaTarget Number | AlphaMin Number | AlphaDecay Number | VelocityDecay Number

data Step selection = Step selection (Array ChainableS) | StepTransformFFI selection (Datum_ -> String)

instance showSimVariable :: Show SimVariable where
  show (Alpha n)         = "Alpha: " <> show n
  show (AlphaTarget n)   = "AlphaTarget: " <> show n
  show (AlphaMin n)      = "AlphaMin: " <> show n
  show (AlphaDecay n)    = "AlphaDecay: " <> show n
  show (VelocityDecay n) = "VelocityDecay: " <> show n

-- TODO we won't export Force constructor here when we close exports
data ForceType = RegularForce RegularForceType | LinkForce | FixForce FixForceType

newtype Force = Force {
    "type"     :: ForceType
  , name       :: Label
  , status     :: ForceStatus
  , filter     :: Maybe ForceFilter
  , attributes :: Array ChainableF
  , force_     :: D3ForceHandle_
}
derive instance Newtype Force _

_name :: Lens' Force Label
_name = _Newtype <<< prop (Proxy :: Proxy "name")
_status :: Lens' Force ForceStatus
_status = _Newtype <<< prop (Proxy :: Proxy "status")
_type :: Lens' Force ForceType
_type = _Newtype <<< prop (Proxy :: Proxy "type")

-- _filter :: forall p row.
--      Newtype Force { filter :: Maybe ForceFilter | row }
--   => Newtype Force { filter :: Maybe ForceFilter | row }
--   => Profunctor p
--   => Strong p
--   => Choice p
--   => p (Datum_ -> Boolean) (Datum_ -> Boolean) -> p Force Force
-- _filter = _Newtype <<< prop (Proxy :: Proxy "filter") <<< _Just <<< _forceFilterFilter

-- getForceFilter :: Force -> (Datum_ -> Boolean)
-- getForceFilter f = do
--   let maybeFilter = view _filter f
--   case maybeFilter of
--     Nothing -> const true -- a slightly expensive NO-OP filter
--     Just filter -> view _forceFilterFilter filter

_filter :: forall p. Profunctor p => Strong p => p (Maybe ForceFilter) (Maybe ForceFilter) -> p Force Force
_filter = _Newtype <<< prop (Proxy :: Proxy "filter")

_filterLabel :: forall p row.
     Newtype Force { filter :: Maybe ForceFilter | row }
  => Newtype Force { filter :: Maybe ForceFilter | row }
  => Profunctor p
  => Strong p
  => Choice p
  => p Label Label -> p Force Force
_filterLabel = _Newtype <<< prop (Proxy :: Proxy "filter") <<< _Just <<< _forceFilterLabel

_attributes :: Lens' Force (Array ChainableF)
_attributes = _Newtype <<< prop (Proxy :: Proxy "attributes")
_force_ :: Lens' Force D3ForceHandle_
_force_ = _Newtype <<< prop (Proxy :: Proxy "force_")

forceTuple :: Force -> Tuple Label Force
forceTuple f = Tuple (view _name f) f

instance Show ForceType where
  show (RegularForce t) = show t
  show LinkForce        = "Link force"
  show (FixForce f)     = show f

instance Show Force where
  show (Force f) = intercalate " " [show f.type, show f.name, show f.status, show f.filter]
  
-- not sure if there needs to be a separate type for force attributes, maybe not, but we'll start assuming so
newtype ChainableF = ForceT AttributeSetter
derive instance Newtype ChainableF _

data ForceStatus = ForceActive | ForceDisabled
derive instance eqForceStatus :: Eq ForceStatus
instance showForceStatus :: Show ForceStatus where
  show ForceActive = "active"
  show ForceDisabled = "inactive"

allNodes :: forall t69. Maybe t69
allNodes = Nothing -- just some sugar so that force declarations are nicer to read, Nothing == No filter == applies to all nodes

-- this filter data type will handle both links and nodes, both considered as opaque type Datum_ and needing coercion
data ForceFilter = ForceFilter Label (Datum_ -> Boolean)
instance Show ForceFilter where
  show (ForceFilter description _) = description

_forceFilterLabel :: Lens' ForceFilter Label
_forceFilterLabel = lens' \(ForceFilter l f) -> Tuple l (\new -> ForceFilter new f)

_forceFilterFilter :: Lens' ForceFilter (Datum_ -> Boolean)
_forceFilterFilter = lens' \(ForceFilter l f) -> Tuple f (\new -> ForceFilter l new)

showForceFilter :: Maybe ForceFilter -> String
showForceFilter (Just (ForceFilter description _)) = description
showForceFilter Nothing = " (no filter)"

data RegularForceType = 
    ForceManyBody -- strength, theta, distanceMax, distanceMin
  | ForceCenter   -- strength, x, y
  | ForceCollide  -- strength, radius, iterations
  | ForceX        -- strength, x
  | ForceY        -- strength, y
  | ForceRadial   -- strength, radius, x, y

data LinkForceType = 
  -- NOTE because data for links can _only_ be provided when setting links in a simulation, initial links array will always be []
  ForceLink     -- strength, distance, iterations, keyFn

data FixForceType =
    ForceFixPositionXY (Datum_ -> Index_ -> { x :: Number, y :: Number }) 
  | ForceFixPositionX  (Datum_ -> Index_ -> { x :: Number })
  | ForceFixPositionY  (Datum_ -> Index_ -> { y :: Number })

data CustomForceType = CustomForce -- TODO need something to hold extra custom force config, perhaps?

instance Show RegularForceType where
  show ForceManyBody          = "ForceManyBody"
  show ForceCenter            = "ForceCenter"
  show ForceCollide           = "ForceCollide"
  show ForceX                 = "ForceX"
  show ForceY                 = "ForceY"
  show ForceRadial            = "ForceRadial"

instance Show LinkForceType where
  show ForceLink              = "ForceLink"

instance Show FixForceType where
  show (ForceFixPositionXY _) = "ForceFixPositionXY"
  show (ForceFixPositionX _)  = "ForceFixPositionX"
  show (ForceFixPositionY _)  = "ForceFixPositionY"


-- unused parameter is to ensure a NEW simulation is created so that, 
-- for example, two Halogen components won't _accidentally_ share one
-- should be dropped later when we can be sure that isn't a problem
-- needs POC with two sims in one page, sim continuing despite page change etc etc
initialSimulationState :: Int -> D3SimulationState_
initialSimulationState id = SimState_
   {  -- common state for all D3 Simulation
      handle_  : initSimulation_ defaultConfigSimulation defaultKeyFunction_
    , selections : {
        nodes: null
      , links: null
    }
    , "data" : {
        nodes: []
      , links: []
    }
    , key          : defaultKeyFunction_

    , forces       : M.empty
    , ticks        : M.empty
    -- parameters of the D3 simulation engine
    , alpha        : defaultConfigSimulation.alpha
    , alphaTarget  : defaultConfigSimulation.alphaTarget
    , alphaMin     : defaultConfigSimulation.alphaMin
    , alphaDecay   : defaultConfigSimulation.alphaDecay
    , velocityDecay: defaultConfigSimulation.velocityDecay
  }
  where
    _ = trace { simulation: "initialized", engineNo: id } \_ -> unit

defaultConfigSimulation :: SimulationConfig_
defaultConfigSimulation = { 
      alpha        : 1.0
    , alphaTarget  : 0.0
    , alphaMin     : 0.0001
    , alphaDecay   : 0.0228
    , velocityDecay: 0.4
}

