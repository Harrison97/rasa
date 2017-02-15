module Rasa.Ext.Views.Internal.Actions
  ( viewports
  , rotate
  , closeInactive
  , focusViewLeft
  , focusViewRight
  , focusViewAbove
  , focusViewBelow
  , hSplit
  , vSplit
  , addSplit
  , nextBuf
  , prevBuf
  , focusDo
  , focusDo_
  , focusedBufs
  , scrollBy
  ) where

import Rasa.Ext
import qualified Rasa.Ext.Views.Internal.Views as V
import Rasa.Ext.Views.Internal.BiTree

import Control.Lens
import Control.Monad
import Data.Maybe
import Data.List

-- | Main export from the views extension, add this to your rasa config.
viewports :: Action ()
viewports = void $ onBufAdded addSplit

-- | Flip all Horizontal splits to Vertical ones and vice versa.
rotate :: Action ()
rotate = V.overWindows V.rotate

-- | Move focus from any viewports one viewport to the left
focusViewLeft :: Action ()
focusViewLeft = V.overWindows V.focusViewLeft

-- | Move focus from any viewports one viewport to the right
focusViewRight :: Action ()
focusViewRight = V.overWindows V.focusViewRight

-- | Move focus from any viewports one viewport above
focusViewAbove :: Action ()
focusViewAbove = V.overWindows V.focusViewAbove

-- | Move focus from any viewports one viewport below
focusViewBelow :: Action ()
focusViewBelow = V.overWindows V.focusViewBelow

-- | Close all inactive viewports
closeInactive :: Action ()
closeInactive = do
  V.Views mWindows <- V.getViews
  V.setViews . V.Views $ mWindows >>= V.closeBy (not . view V.active)

-- | Split active views horizontally
hSplit :: Action ()
hSplit = V.overWindows V.hSplit

-- | Split active views vertically
vSplit :: Action ()
vSplit = V.overWindows V.vSplit

-- | Add a new split at the top level in the given direction containing the given buffer.
addSplit :: BufAdded -> Action ()
addSplit (BufAdded bRef) = do
  V.Views mWin <- V.getViews
  case mWin of
    Nothing -> V.setViews . V.Views . Just $ Leaf (V.View True (V.BufView bRef) 0)
    Just win -> V.setViews .  V.Views . Just $ V.addSplit V.Vert (V.BufView bRef) win

-- | Select the next buffer in any active viewports
nextBuf :: Action ()
nextBuf = V.traverseViews next
  where
    next vw
      | vw ^. V.active = do
        newViewable <- getNextBufRef (vw^. V.viewable)
        return (vw &  V.viewable .~ newViewable)
      | otherwise = return vw

    getNextBufRef (V.BufView br) = V.BufView <$> nextBufRef br
    getNextBufRef v = return v

-- | Select the previous buffer in any active viewports
prevBuf :: Action ()
prevBuf = V.traverseViews prev
  where
    prev vw
      | vw ^. V.active = do
        newViewable <- getPrevBufRef (vw^. V.viewable)
        return (vw &  V.viewable .~ newViewable)
      | otherwise = return vw

    getPrevBufRef (V.BufView br) = V.BufView <$> prevBufRef br
    getPrevBufRef v = return v

-- | Get bufRefs for all buffers that are selected in at least one viewport
focusedBufs :: Action [BufRef]
focusedBufs = do
  V.Views mWindows <- V.getViews
  case mWindows of
    Nothing -> return []
    Just win -> return . nub . activeBufRefs $ win
  where activeBufRefs = toListOf $ traverse . filtered (view V.active) . V.viewable . V._BufViewRef

-- | Run a bufAction over all focused buffers and return any results.
focusDo :: BufAction a -> Action [a]
focusDo bufAct = do
  bufRefs <- focusedBufs
  catMaybes <$> mapM (`bufDo` bufAct) bufRefs

-- | 'focusDo' with a void return
focusDo_ :: BufAction a -> Action ()
focusDo_ = void . focusDo

scrollBy :: Int -> Action ()
scrollBy amt = V.overWindows $ V.scrollBy amt
