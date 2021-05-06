module D3.Selection where

import D3.Attributes.Instances
import D3.FFI
import Prelude hiding (append,join)

import D3.Data.Types
import Data.Maybe.Last (Last)
import Effect.Aff (Milliseconds)
import Unsafe.Coerce (unsafeCoerce)

type D3Selection  = Last D3Selection_
data Keys = ComputeKey ComputeKeyFunction_ | UseDatumAsKey
-- TODO hide the "unsafeCoerce/makeProjection" in a smart constructor
type Projection = forall model. (model -> D3Data_)
identityProjection :: Projection
identityProjection model = unsafeCoerce (\d -> d)

makeProjection :: forall model model'. (model -> model') -> (model -> D3Data_)
makeProjection = unsafeCoerce

data DragBehavior = 
    DefaultDrag
  | NoDrag
  | CustomDrag (D3Selection_ -> Unit)

data SimulationDrag = SimulationDrag DragBehavior


type JoinParams d r = -- the 
  { element    :: Element -- what we're going to insert in the DOM
  , key        :: Keys    -- how D3 is going to identify data so that 
  , "data"     :: Array d -- the data we're actually joining at this point
 
| r
  }
-- TODO the type parameter d here is an impediment to the meta interpreter, possible rethink ?
data Join d = Join           (JoinParams d (behaviour   :: Array Chainable))
            | JoinGeneral    (JoinParams d (behaviour   :: EnterUpdateExit)) -- what we're going to do for each set (enter, exit, update) each refresh of data
            | JoinSimulation (JoinParams d (behaviour   :: Array Chainable
                                          , onTick      :: Array Chainable
                                          , tickName    :: String
                                          , onDrag      :: SimulationDrag
                                          , simulation  :: D3Simulation_)) -- simulation joins are a bit different
newtype SelectionName = SelectionName String
derive instance eqSelectionName  :: Eq SelectionName
derive instance ordSelectionName :: Ord SelectionName

data D3_Node = D3_Node Element (Array Chainable)

instance showD3_Node :: Show D3_Node where
  show (D3_Node e cs) = "D3Node: " <> show e

-- sugar for appending with no attributes
node :: Element -> (Array Chainable) -> D3_Node
node e a = D3_Node e a

node_ :: Element -> D3_Node
node_ e = D3_Node e []


data Chainable =  AttrT Attribute
                | TextT Attribute -- we can't narrow it to String here but helper function will do that
                | TransitionT (Array Chainable) Transition -- the array is set situationally
                | RemoveT
                | OnT MouseEvent Listener_
  -- other candidates for this ADT include
                -- | WithUnit Attribute UnitType
                -- | Merge
                
type EnterUpdateExit = {
    enter  :: Array Chainable
  , update :: Array Chainable
  , exit   :: Array Chainable
}

enterOnly :: Array Chainable -> EnterUpdateExit
enterOnly as = { enter: as, update: [], exit: [] }

instance showChainable :: Show Chainable where
  show (AttrT attr)      = attrLabel attr
  show (TextT _)         = "text"
  show (TransitionT _ _) = ""
  show RemoveT           = ""
  show (OnT event _)     = show event