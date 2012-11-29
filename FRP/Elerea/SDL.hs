module FRP.Elerea.SDL (sdlLoop, Ticks) where

import Data.Word (Word32)
import System.IO.Unsafe
import Control.Concurrent (threadDelay)

import FRP.Elerea.Param
import qualified Graphics.UI.SDL as SDL

-- | SDL Ticks
type Ticks = Word32

-- | Main SDL event loop (with framerate)
--
-- Produces an "infinite" list of network samples
sdlLoop ::
	Ticks
	-- ^ Frame duration / Frame time
	-> (SignalGen Ticks (Signal [SDL.Event]) -> SignalGen Ticks (Signal a))
	-- ^ 'Signal' network, takes event 'SignalGen' as argument
	-> IO [a]
sdlLoop frameTime network = do
	(events, signalEvents) <- externalMulti
	sampleNetwork <- start (network events)
	now <- SDL.getTicks
	sdlLoop' signalEvents sampleNetwork frameTime now

sdlLoop' ::
	(SDL.Event -> IO ()) -- ^ IO action to signal an event
	-> (Ticks -> IO a)   -- ^ IO action to sample the network
	-> Ticks             -- ^ Frame duration / Frame time
	-> Ticks             -- ^ Current SDL time (getTicks)
	-> IO [a]
sdlLoop' signalEvents sampleNetwork frameTime = loop frameTime
	where
	loop timeLeft time = do
		(event, (left, nextTime)) <- waitEventTimeout (timeLeft, time)
		case event of
			(Just e) -> signalEvents e >> loop left nextTime
			Nothing -> do
				x <- sampleNetwork nextTime
				xs <- unsafeInterleaveIO (loop frameTime nextTime)
				return (x : xs)

-- | Turns out, SDL just does poll-and-wait internally anyway
--   This wait can time out, which is useful for drawing
waitEventTimeout :: (Ticks,Ticks) -> IO (Maybe SDL.Event, (Ticks,Ticks))
waitEventTimeout (initialLeft, lastTime) = do
	SDL.pumpEvents
	e <- SDL.pollEvent
	case e of
		SDL.NoEvent -> do
			now <- SDL.getTicks
			loop (initialLeft `sub` (now-lastTime)) now
		_ -> return (Just e, (initialLeft, lastTime))
	where
	loop 0 _ = do
		timeoutNow <- SDL.getTicks
		return (Nothing, (0, timeoutNow))
	loop _ now = do
		SDL.pumpEvents
		e <- SDL.pollEvent
		case e of
			SDL.NoEvent -> do
				threadDelay 10000
				eventNow <- SDL.getTicks
				loop (initialLeft `sub` (eventNow - now)) now
			_ -> do
				eventNow <- SDL.getTicks
				return (Just e, (initialLeft `sub` (eventNow - now), eventNow))
	sub t n
		| t > n = t - n
		| otherwise = 0
