module Cannon.Dict
    ( Dict
    , empty
    , add
    , insert
    , remove
    , removeIf
    , lookup
    , size
    )
where

import Imports hiding (lookup)

import Data.Hashable (hash, Hashable)
import Data.SizedHashMap (SizedHashMap)
import Data.Vector (Vector, (!))

import qualified Data.SizedHashMap as SHM
import qualified Data.Vector       as V


newtype Dict a b = Dict
    { _map :: Vector (IORef (SizedHashMap a b)) }

size :: MonadIO m => Dict a b -> m Int
size d = liftIO $ sum <$> mapM (\r -> SHM.size <$> readIORef r) (_map d)

empty :: MonadIO m => Int -> m (Dict a b)
empty w = liftIO $ if w > 0 && w < 8192
    then Dict <$> V.generateM w (const $ newIORef SHM.empty)
    else error "Dict.empty: slice number out of range [1, 8191]"

insert :: (Eq a, Hashable a, MonadIO m) => a -> b -> Dict a b -> m ()
insert k v = mutDict (SHM.insert k v) . getSlice k

add :: (Eq a, Hashable a, MonadIO m) => a -> b -> Dict a b -> m Bool
add k v d = liftIO $ atomicModifyIORef' (getSlice k d) $ \m ->
    if k `elem` SHM.keys m
        then (m, False)
        else (SHM.insert k v m, True)

remove :: (Eq a, Hashable a, MonadIO m) => a -> Dict a b -> m Bool
remove = removeIf (const True)

removeIf :: (Eq a, Hashable a, MonadIO m) => (Maybe b -> Bool) -> a -> Dict a b -> m Bool
removeIf f k d = liftIO $ atomicModifyIORef' (getSlice k d) $ \m ->
    if f (SHM.lookup k m)
        then (SHM.delete k m, True)
        else (m, False)

lookup :: (Eq a, Hashable a, MonadIO m) => a -> Dict a b -> m (Maybe b)
lookup k = liftIO . fmap (SHM.lookup k) . readIORef . getSlice k

-----------------------------------------------------------------------------
-- Internal

mutDict :: MonadIO m
        => (SizedHashMap a b -> SizedHashMap a b)
        -> IORef (SizedHashMap a b)
        -> m ()
mutDict f d = liftIO $ atomicModifyIORef' d $ \m -> (f m, ())

getSlice :: (Hashable a) => a -> Dict a b -> IORef (SizedHashMap a b)
getSlice k (Dict m) = m ! (hash k `mod` V.length m)
