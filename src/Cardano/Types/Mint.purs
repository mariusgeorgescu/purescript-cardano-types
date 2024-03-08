module Cardano.Types.Mint
  ( Mint(Mint)
  , empty
  , flatten
  , unflatten
  , toCsl
  , fromCsl
  ) where

import Prelude

import Aeson (class DecodeAeson, class EncodeAeson, decodeAeson, encodeAeson)
import Cardano.Serialization.Lib (packMapContainer, unpackMapContainerToMapWith)
import Cardano.Serialization.Lib as Csl
import Cardano.Types.AssetName (AssetName)
import Cardano.Types.Int as Int
import Cardano.Types.MultiAsset as MultiAsset
import Cardano.Types.ScriptHash (ScriptHash)
import Data.Array (foldM)
import Data.Generic.Rep (class Generic)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe)
import Data.Newtype (class Newtype, unwrap, wrap)
import Data.Show.Generic (genericShow)
import Data.These (These(Both, That, This))
import Data.Traversable (traverse)
import Data.Tuple.Nested ((/\), type (/\))

newtype Mint = Mint (Map ScriptHash (Map AssetName Int.Int))

derive instance Generic Mint _
derive newtype instance Eq Mint
derive instance Newtype Mint _
-- no Ord instance to prevent confusion

instance Show Mint where
  show = genericShow

instance EncodeAeson Mint where
  encodeAeson = toCsl >>> encodeAeson

instance DecodeAeson Mint where
  decodeAeson = map fromCsl <<< decodeAeson

empty :: Mint
empty = Mint Map.empty

singleton :: ScriptHash -> AssetName -> Int.Int -> Mint
singleton sh an n = Mint (Map.singleton sh (Map.singleton an n))

flatten :: Mint -> Array (ScriptHash /\ AssetName /\ Int.Int)
flatten (Mint mp) =
  Map.toUnfoldable mp >>= \(sh /\ mp') -> do
    Map.toUnfoldable mp' >>= \(tn /\ amount) -> pure (sh /\ tn /\ amount)

unflatten :: Array (ScriptHash /\ AssetName /\ Int.Int) -> Maybe Mint
unflatten =
  foldM accumulate empty
  where
  uncurry2 f (a /\ b /\ c) = f a b c
  accumulate ma = unionWithNonAda Int.add ma <<< uncurry2 singleton

unionWithNonAda
  :: (Int.Int -> Int.Int -> Maybe Int.Int)
  -> Mint
  -> Mint
  -> Maybe Mint
unionWithNonAda f ls rs =
  let
    combined :: Map ScriptHash (Map AssetName (These Int.Int Int.Int))
    combined = unionNonAda ls rs

    unBoth :: These Int.Int Int.Int -> Maybe Int.Int
    unBoth k' = case k' of
      This a -> f a Int.zero
      That b -> f Int.zero b
      Both a b -> f a b
  in
    normalizeMint <<< Mint <$> traverse (traverse unBoth) combined

normalizeMint :: Mint -> Mint
normalizeMint = filterMint (notEq Int.zero)

filterMint :: (Int.Int -> Boolean) -> Mint -> Mint
filterMint p (Mint mp) =
  Mint $ Map.filter (not Map.isEmpty) $ Map.filter p <$> mp

unionNonAda
  :: Mint
  -> Mint
  -> Map ScriptHash (Map AssetName (These Int.Int Int.Int))
unionNonAda (Mint l) (Mint r) =
  let
    combined
      :: Map ScriptHash
           (These (Map AssetName Int.Int) (Map AssetName Int.Int))
    combined = MultiAsset.union l r

    unBoth
      :: These (Map AssetName Int.Int) (Map AssetName Int.Int)
      -> Map AssetName (These Int.Int Int.Int)
    unBoth k = case k of
      This a -> This <$> a
      That b -> That <$> b
      Both a b -> MultiAsset.union a b
  in
    unBoth <$> combined

toCsl :: Mint -> Csl.Mint
toCsl (Mint mp) = packMapContainer $ Map.toUnfoldable mp <#> \(scriptHash /\ mintAssets) ->
  unwrap scriptHash /\
    packMapContainer do
      Map.toUnfoldable mintAssets <#> \(assetName /\ quantity) -> do
        unwrap assetName /\ unwrap quantity

fromCsl :: Csl.Mint -> Mint
fromCsl = wrap <<< unpackMapContainerToMapWith wrap
  (unpackMapContainerToMapWith wrap wrap)
