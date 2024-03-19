module Cardano.Types.CostModel where

import Prelude

import Aeson (class EncodeAeson, class DecodeAeson)
import Cardano.Serialization.Lib
  ( costModel_get
  , costModel_len
  , costModel_new
  , costModel_set
  )
import Cardano.Serialization.Lib as Csl
import Cardano.Types.Int (Int) as Int
import Data.Array as Array
import Data.FoldableWithIndex (forWithIndex_)
import Data.Generic.Rep (class Generic)
import Data.Int (toNumber) as Int
import Data.Int as PInt
import Data.Maybe (fromJust)
import Data.Newtype (class Newtype, unwrap, wrap)
import Data.Show.Generic (genericShow)
import Data.Traversable (for)
import Effect.Unsafe (unsafePerformEffect)
import Partial.Unsafe (unsafePartial)

newtype CostModel = CostModel (Array Int.Int)

derive instance Newtype CostModel _
derive instance Generic CostModel _
derive newtype instance Eq CostModel
derive newtype instance Ord CostModel
derive newtype instance EncodeAeson CostModel
derive newtype instance DecodeAeson CostModel

instance Show CostModel where
  show = genericShow

toCsl :: CostModel -> Csl.CostModel
toCsl (CostModel mdls) = unsafePerformEffect do
  mdl <- costModel_new
  forWithIndex_ mdls \i c ->
    costModel_set mdl (Int.toNumber i) $ unwrap c
  pure mdl

fromCsl :: Csl.CostModel -> CostModel
fromCsl mdl = CostModel $ unsafePerformEffect do
  length <- unsafePartial $ fromJust <<< PInt.fromNumber <$> costModel_len mdl
  for (Array.range 0 $ length - 1) \ix -> do
    wrap <$> costModel_get mdl (Int.toNumber ix)
