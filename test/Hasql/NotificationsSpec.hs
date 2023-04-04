module Hasql.NotificationsSpec (main, spec) where

import Test.Hspec
import Test.QuickCheck

import Control.Concurrent (forkIO, killThread)
import Control.Concurrent.MVar
import Control.Monad (void)
import System.Exit (die)
import Data.ByteString

import Hasql.Connection
import Hasql.Notifications

-- `main` is here so that this module can be run from GHCi on its own.  It is
-- not needed for automatic spec discovery.
main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "send and receive notification" $
    describe "when I send a notification to channel my handler is listening to" $
      it "should call our notification handler" $ do
        dbOrError <- acquire "postgres://postgres:postgres@localhost"
        case dbOrError of
            Right db -> do
                let channelToListen = toPgIdentifier "test-channel"
                mailbox <- newEmptyMVar :: IO (MVar ByteString)
                listen db channelToListen
                threadId <- forkIO $ waitForNotifications (\channel payload -> putMVar mailbox $ "Just got notification on channel " <> channel <> ": " <> payload) db
                notifyDbOrError <- acquire "postgres://postgres:postgres@localhost"
                case notifyDbOrError of
                  Right notifyDb -> do
                    notify notifyDb channelToListen "Payload"
                    takeMVar mailbox `shouldReturn` "Just got notification on channel test-channel: Payload"
                  Left _ -> die "Could not open database connection"
            _ -> die "Could not open database connection"

  describe "toPgIdenfier" $
    it "enclose text in quotes doubling existing ones" $
      fromPgIdentifier (toPgIdentifier "some \"identifier\"") `shouldBe` "\"some \"\"identifier\"\"\""