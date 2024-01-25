module Cardano.Types.Relay where

import Prelude

import Control.Alt ((<|>))
import Aeson (class EncodeAeson)
import Cardano.Serialization.Lib
  ( dnsRecordAorAAAA_new
  , dnsRecordAorAAAA_record
  , dnsRecordSRV_new
  , dnsRecordSRV_record
  , multiHostName_dnsName
  , multiHostName_new
  , relay_asMultiHostName
  , relay_asSingleHostAddr
  , relay_asSingleHostName
  , relay_newMultiHostName
  , relay_newSingleHostAddr
  , relay_newSingleHostName
  , singleHostAddr_ipv4
  , singleHostAddr_ipv6
  , singleHostAddr_new
  , singleHostAddr_port
  , singleHostName_dnsName
  , singleHostName_new
  , singleHostName_port
  )
import Cardano.Serialization.Lib as Csl
import Cardano.Types.Internal.Helpers (encodeTagged')
import Cardano.Types.Ipv4 (Ipv4)
import Cardano.Types.Ipv6 (Ipv6)
import Data.Generic.Rep (class Generic)
import Data.Int as Int
import Data.Maybe (Maybe, fromJust, fromMaybe)
import Data.Newtype (unwrap, wrap)
import Data.Nullable (toMaybe, toNullable)
import Data.Show.Generic (genericShow)
import Literals.Undefined (undefined)
import Partial.Unsafe (unsafePartial)
import Unsafe.Coerce (unsafeCoerce)

-- Here we collapse some trivial intermediate CSL wrapper types into anonymous
-- records, namely:
-- - SingleHostAddr
-- - SingleHostName
-- - MultiHostName
data Relay
  = SingleHostAddr
      { port :: Maybe Int
      , ipv4 :: Maybe Ipv4
      , ipv6 :: Maybe Ipv6
      }
  | SingleHostName
      { port :: Maybe Int
      , dnsName :: String
      }
  | MultiHostName { dnsName :: String }

derive instance Eq Relay
derive instance Ord Relay
derive instance Generic Relay _

instance Show Relay where
  show = genericShow

instance EncodeAeson Relay where
  encodeAeson = case _ of
    SingleHostAddr r -> encodeTagged' "SingleHostAddr" r
    SingleHostName r -> encodeTagged' "SingleHostName" r
    MultiHostName r -> encodeTagged' "MultiHostName" r

toCsl :: Relay -> Csl.Relay
toCsl = case _ of
  SingleHostAddr { port, ipv4, ipv6 } ->
    relay_newSingleHostAddr $ singleHostAddr_new
      -- TODO: the type signatures are wrong in ps-csl, because the codegen hasn't been adapted to handle this case. It only happens once.
      -- https://github.com/mlabs-haskell/purescript-cardano-serialization-lib/issues/1
      (fromMaybe (unsafeCoerce undefined) $ Int.toNumber <$> port)
      (fromMaybe (unsafeCoerce undefined) $ unwrap <$> ipv4)
      (fromMaybe (unsafeCoerce undefined) $ unwrap <$> ipv6)
  SingleHostName { port, dnsName } ->
    relay_newSingleHostName $ singleHostName_new
      (toNullable $ Int.toNumber <$> port)
      (dnsRecordAorAAAA_new dnsName)
  MultiHostName { dnsName } ->
    relay_newMultiHostName $ multiHostName_new $ dnsRecordSRV_new dnsName

fromCsl :: Csl.Relay -> Relay
fromCsl csl = unsafePartial $ fromJust $
  singleHostAddr <|> singleHostName <|> multiHostName
  where
  singleHostAddr = toMaybe (relay_asSingleHostAddr csl) <#>
    singleHostAddrFromCsl >>> SingleHostAddr

  singleHostAddrFromCsl
    :: Csl.SingleHostAddr
    -> { port :: Maybe Int
       , ipv4 :: Maybe Ipv4
       , ipv6 :: Maybe Ipv6
       }
  singleHostAddrFromCsl sha =
    { port: unsafePartial $ fromJust <<< Int.fromNumber <$> toMaybe (singleHostAddr_port sha)
    , ipv4: wrap <$> toMaybe (singleHostAddr_ipv4 sha)
    , ipv6: wrap <$> toMaybe (singleHostAddr_ipv6 sha)
    }

  singleHostName = toMaybe (relay_asSingleHostName csl) <#>
    singleHostNameFromCsl >>> SingleHostName

  singleHostNameFromCsl
    :: Csl.SingleHostName
    -> { port :: Maybe Int
       , dnsName :: String
       }
  singleHostNameFromCsl shn =
    { port: unsafePartial $ fromJust <<< Int.fromNumber <$> toMaybe (singleHostName_port shn)
    , dnsName: dnsRecordAorAAAA_record $ singleHostName_dnsName shn
    }

  multiHostName = toMaybe (relay_asMultiHostName csl) <#>
    multiHostNameFromCsl >>> MultiHostName

  multiHostNameFromCsl :: Csl.MultiHostName -> { dnsName :: String }
  multiHostNameFromCsl mhn = { dnsName: dnsRecordSRV_record $ multiHostName_dnsName mhn }
