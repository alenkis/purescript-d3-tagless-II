module D3.Interpreter.Tagless where

import Control.Monad.State (class MonadState, StateT, get, modify, put, runStateT)
import D3.Attributes.Instances (Attribute(..), unbox)
import D3.Selection (D3Selection, D3_Node(..), Element, EnterUpdateExit, Selector, TransitionStep, coerceD3Data, d3AddTransition, d3Append_, d3Data_, d3Exit_, d3RemoveSelection_, d3SelectAllInDOM_, d3SelectionSelectAll_, d3SetAttr_, emptyD3Selection)
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..), fst, snd)
import Effect (Effect)
import Effect.Class (class MonadEffect)
import Prelude (class Applicative, class Apply, class Bind, class Functor, class Monad, Unit, bind, discard, liftA1, pure, show, ($), (<$>))
import Unsafe.Coerce (unsafeCoerce)

newtype D3M a = D3M (StateT D3Selection Effect a) -- not using Effect to keep sigs simple for now

derive newtype instance functorD3M     :: Functor           D3M
derive newtype instance applyD3M       :: Apply             D3M
derive newtype instance applicativeD3M :: Applicative       D3M
derive newtype instance bindD3M        :: Bind              D3M
derive newtype instance monadD3M       :: Monad             D3M
derive newtype instance monadStateD3M  :: MonadState D3Selection D3M
derive newtype instance monadEffD3M    :: MonadEffect       D3M

class (Monad m) <= D3Tagless m where
  hook   :: Selector -> m D3Selection
  append :: D3_Node -> m D3Selection
  join   :: Element -> EnterUpdateExit -> m D3Selection

runD3M :: ∀ a. D3M a -> D3Selection -> Effect (Tuple a D3Selection)
runD3M (D3M selection) = runStateT selection

d3State :: ∀ a. D3M a -> Effect D3Selection
d3State (D3M selection) = liftA1 snd $ runStateT selection emptyD3Selection

d3Run :: ∀ a. D3M a -> Effect a
d3Run (D3M selection) = liftA1 fst $ runStateT selection emptyD3Selection

instance d3TaglessD3M :: D3Tagless D3M where
  hook selector = modify $ d3SelectAllInDOM_ selector

  append node = modify $ doAppend node

  join element enterUpdateExit = do -- TODO add data to the join
    selection <- get
    let -- TOOD d3Data_ with data
        initialS = d3SelectionSelectAll_ (show element) selection
        -- TODO this is where it's really tricky - attribute processing with shape of data open
        updateS  = d3Data_ (coerceD3Data [1,2,3]) initialS 
        _ = foldl doTransitionStep updateS enterUpdateExit.update

        enterS  = d3Append_ (show element) updateS -- TODO add Attrs for the inserted element here
        _      = foldl doTransitionStep enterS enterUpdateExit.enter

        exitS   = d3Exit_ updateS
        _       = foldl doTransitionStep exitS enterUpdateExit.exit
        _       = d3RemoveSelection_ exitS -- TODO this is actually optional but by far more common to always remove

    put updateS -- not clear to me what actually has to be returned from join
    pure updateS

doTransitionStep :: D3Selection -> TransitionStep -> D3Selection
doTransitionStep selection (Tuple attributes (Just transition)) = do
  let _ = (setAttributeOnSelection selection) <$> attributes
  -- returning the transition as a "selection"
  d3AddTransition selection transition
doTransitionStep selection (Tuple attributes Nothing) = do -- last stage of chain
  let _ = (setAttributeOnSelection selection) <$> attributes
  selection -- there's no next stage at end of chain, this "selection" might well be a "transition" but i don't think we care

doAppend :: D3_Node -> D3Selection -> D3Selection
doAppend (D3_Node element attributes children) selection = do
  let appended = d3Append_ (show element) selection
      _ = d3SetAttr_ "x" (unsafeCoerce "foo") appended
      _ = (setAttributeOnSelection appended) <$> attributes
      _ = (addChildToExisting appended) <$> children
  appended

addChildToExisting :: D3Selection -> D3_Node -> D3Selection
addChildToExisting selection (D3_Node element attributes children) = do
    let appended = d3Append_ (show element) selection
        _ = d3SetAttr_ "x" (unsafeCoerce "baar") appended
        _ = (setAttributeOnSelection appended) <$> attributes
    appended

setAttributeOnSelection :: D3Selection -> Attribute -> Unit
setAttributeOnSelection selection (Attribute label attr) = d3SetAttr_ label (unbox attr) selection

appendChildToSelection :: D3Selection -> D3_Node -> D3Selection
appendChildToSelection selection (D3_Node element attributes children)  = d3Append_ (show element) selection

