{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns      #-}

-- | This module exports types and functions from Database.CQL.IO, while adding a few wire specific functions.
module Cassandra.Settings
  ( module C
  , initialContactsDisco
  , initialContactsPlain
  ) where

import Imports
import Control.Lens
import Data.Aeson.Lens
import Database.CQL.IO as C (Settings, Policy, setLogger, setPolicy, setRetrySettings, setResponseTimeout, setPrepareStrategy, setMaxTimeouts, setSendTimeout, setConnectTimeout, setPoolStripes, setMaxStreams, setMaxConnections, setIdleTimeout, setPortNumber, setKeyspace, addContact, setContacts, setCompression, setProtocolVersion, defSettings)
import Database.CQL.IO.Tinylog as C (mkLogger)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (pack, stripSuffix, unpack)
import Network.Wreq

-- | This function is likely only useful at Wire, as it is Wire-infra specific.
-- Given a server name and a url returning a wire-custom "disco" json (AWS describe-instances-like json), e.g.
-- { "roles" : { "server_name": [ {"privateIpAddress": "...", ...}, {...} ] } },
-- return a list of IP addresses.
initialContactsDisco :: MonadIO m => String -> String -> m (NonEmpty String)
initialContactsDisco (pack -> srv) url = liftIO $ do
    rs <- asValue =<< get url
    let srvs = case stripSuffix "_seed" srv of
                   Nothing -> [srv, srv <> "_seed"]
                   Just _  -> [srv] -- requesting only seeds is a valid use-case
    let ip = rs ^.. responseBody
                  . key "roles"
                  . members
                  . indices (`elem` srvs)
                  . values
                  . key "privateIpAddress"
                  . _String
                  & map unpack
    case ip of
        i:ii -> return (i :| ii)
        _    -> error "initial-contacts: no IP addresses found."

-- | Puts the address into a list using the same signature as the other initialContacts
initialContactsPlain :: MonadIO m => Text -> m (NonEmpty String)
initialContactsPlain address = pure $ unpack address :| []
