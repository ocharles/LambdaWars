module Engine where

import System.Random
import Control.Monad.Random
import Control.Monad.Random.Class
import Control.Monad.Loops
import Data.List
import Data.Label.Pure
import Debug.Trace

-- Vectors
--import Data.Vector.Fancy 
import Data.Vector.V2 
import Data.Vector.Transform.T2 
import Data.Angle 
import Data.Vector.Transform.Fancy 
import Data.Vector.Class

import Control.Applicative

import Core
import GeometryUtils
import Data.Label.Pure
import WorldRules
import TupleUtils

-- | Random instances used for generating bot starting positions
instance Random Point where
  random               = runRand $ Vector2 <$> getRandom <*> getRandom
  randomR (from, to)   = runRand $ Vector2 <$> (getRandomR ((v2x from), (v2x to)))
                                           <*> (getRandomR ((v2y from), (v2y to)))

instance Random (Double, Double) where
  random = runRand $ do v1 <- getRandom
                        v2 <- getRandom
                        return (v1,v2)
  
  randomR (from, to) = runRand $ do v1 <- getRandomR (fst from, fst to)
                                    v2 <- getRandomR (snd from, snd to)
                                    return (v1,v2)
  
instance Random BotState where
  random = runRand $ do 
    position <- getRandomR (Vector2 0 0, Vector2 arenaWidth arenaHeight)
    let zero = Vector2 0 0
      in return $ BotState position zero zero zero NoAction
                          
  randomR (from, to)   = runRand $ let zero  = Vector2 0 0
                                       fromP = get botPosition from :: Point
                                       toP   = get botPosition to
                                   in do 
                                     position <- getRandomR (fromP, toP)
                                     return $ BotState position zero zero zero NoAction
                                   
-- |Generates non overlapping bot states, we don't want to start with collisions
instance Random [BotState] where
  random g =  (nubBy botBotCollision states, head gs)
    where 
      (states, gs) = unzip $ unfoldr f g 
      f g = Just ((next, gNext), gNext)
        where (next, gNext) = random g
              
              
-- | TODO Ensure that the bot can't turn by more then permitted by the rules etc.
sanitizeCommand :: Command -> Command
sanitizeCommand = id

-- | Create a new BotState given a command issued by the bot
stepBotState :: Command -> BotState -> BotState
stepBotState cmd = apply cmd . moveBot
  where
    apply NoAction = id
    apply (Accelerate delta)   = modify botVelocity $ vmap (+delta)
    apply (Decelerate delta)   = modify botVelocity $ vmap (+ (-delta))
    apply (Turn       degrees) = modify botVelocity $ rotate degrees   
    apply (MoveTurret degrees) = modify botTurret   $ rotate degrees     
    apply (MoveRadar  degrees) = modify botRadar    $ rotate degrees 
    
    moveBot state = modify botPosition (+ get botVelocity state) state

bulletsFired :: [(Step, BotState)] -> [Bullet]
bulletsFired bots = map (fire . snd) $ filter hasFired bots
  where hasFired (step, _) = stepCmd step == Fire

-- | Returns a bullet traveling the direction the bot turret is pointing
fire :: BotState -> Bullet
fire state = Bullet position velocity 
  where position = get botPosition state
        velocity = vnormalise (get botTurret state) |* (fromInteger bulletSpeed)

-- | TODO Return true if the bots are colliding 
botBotCollision :: BotState -> BotState -> Bool
botBotCollision bot1 bot2 = False

-- | TODO Returns true if this bot is colliding with a wall
botWallCollision :: BotState -> Bool
botWallCollision state = False

-- TODO scan results and collision results
newDashBoard :: [BotState] -> BotState -> DashBoard
newDashBoard otherBots bot = DashBoard NothingFound NoCollision (get botVelocity bot) 

-- | TODO this function steps the world - 
--   for now it does not hit test bullets or test for collisions
stepWorld :: World -> World
stepWorld (World bots bullets bbox) = World (zip newSteps newStates) newBullets bbox
  where         
    steps      = map mkSteps bots
    newBullets = map stepBullet $ bullets ++ bulletsFired steps
    commands   = map (sanitizeCommand . stepCmd . fst) steps
    newStates  = map (uncurry stepBotState ) $ zip commands $ map snd bots
    newSteps   = map (stepNext . fst) steps
    mkSteps bot@(automaton, state) = (step dashboard automaton, state)
      where dashboard = newDashBoard otherBots state
            otherBots = filter (== state) . map snd $ bots
            
-- | Step bullet
stepBullet :: Bullet -> Bullet                  
stepBullet bullet = modify bulletPosition (+ get bulletVelocity bullet) bullet

-- | Returns true if the match is over
matchIsOver :: World -> Bool  
matchIsOver (World bots _  _) = length bots < 2
  
-- | Generate a new random world with the supplied bots                                
newWorld :: RandomGen g => g -> [Bot a] -> World
newWorld gen bots = World (zip automata states) [] arenaBBox
  where states   = take (length bots) . fst $ random gen
        automata = map start bots                       
        zero     = Vector2 0 0

  
  
  
  
