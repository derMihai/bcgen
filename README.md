# bcgen - The Balanced (and Better) Catan Map Generator

I wanted to learn Zig and create something useful. No AI involved.

From `bcgen --help`:

```
bcgen - the balanced (and better) Catan map generator!

Generates a randomized Catan board with balanced resource spread and yields.
Losing is now purely due to skill issues!

TL;DR:
 Run this program, try again if it fails.

Glossary:
 - Field: a hexagon tile that holds a resource
 - Zone: a cluster of three fields neighboring each other, i.e. any three
   fields that can be occupied by one settlement. There are 23 of them.
 - Yield number: the numbers (2 to 12) placed on a field
 - Field yield: the expected number of resources a yield number gives on a
   dice roll, i.e. the probability of rolling that number:
    2, 12:  1/30 ~ 0.033
    3, 11:  2/30 ~ 0.067
    4, 10:  3/30 ~ 0.1
    5,  9:  4/30 ~ 0.133
    6,  8:  5/30 ~ 0.167
   For internal calculations, the yield of the Desert field is 0.1.
 - Zone yield: the sum of the yields in a zone. Ranges between 4/30 (i.e. 
   2, 12, 3) and 15/30 (i.e. 6, 6, 8).
 - Resource yield: the sum of the yields of all the fields sharing the same
   resource, divided by the number of fields. E.g. for Clay with yield 
   numbers 2, 3, 10 this is (1 + 2 + 3) / 30 / 3 = 0.1;
 - Clump: a pair of neighboring fields sharing the same resource.

How it works:
 The generation takes place in three steps:
  1. Field resource assignment with spread balancing. The resources are
     disitributed s.t. no clumps are formed (i.e. no neighboring fields share 
     the same resource.
  2. Field yield number assignment with zone yield balancing. The yield 
     numbers are distributed randomly, then they are swapped until the 
     difference between the lowest and the highest zone yields is less or
     equal to `--max-zdiff`. To avoid clustering of either high or low yields 
     around the Desert field, its yield is set to the fixed mean value of 3. 
     If this step fails, start over from 1.
  3. Resource yield balancing. Resources are swapped until the difference
     between the lowest and the highest resource yields is lower or equal
     to `--max-rdiff`. If this step fails, or if at the end the number of
     clumps is larger than `--max-clumps`, start over from 1.
 
 The number of attempts is capped and the program will fail on exhaustion. Try 
 again with a different seed or relax the constraints.
 ```

 Example:
 ```
$ bcgen --max-clumps 0 --mid-desert --stats
generating with seed 18077981963899159449...
      / \ / \ / \     
     |🪨 |🌲 |🧱 |    
    / \ / \ / \ / \   
   |🌲 |🐑 |🌾 |🐑 |  
  / \ / \ / \ / \ / \ 
 |🌾 |🧱 |🪾 |🪨 |🌲 |
  \ / \ / \ / \ / \ / 
   |🐑 |🪨 |🐑 |🌾 |  
    \ / \ / \ / \ /   
     |🌾 |🧱 |🌲 |    
      \ / \ / \ /     
      / \ / \ / \     
     |10 |10 | 6 |    
    / \ / \ / \ / \   
   | 5 | 4 | 4 |12 |  
  / \ / \ / \ / \ / \ 
 |11 | 5 | 0 | 9 | 8 |
  \ / \ / \ / \ / \ / 
   | 9 | 3 | 6 |11 |  
    \ / \ / \ / \ /   
     | 8 | 2 | 3 |    
      \ / \ / \ /     
clumps               = 0
zone diff            = 0.100
resource diff (norm) = 0.017
Resource yield:
  res        yield  norm yield
  Clay        0.33       0.111
  Sheep       0.43       0.108
  Minerals    0.30       0.100
  Grains      0.40       0.100
  Wood        0.47       0.117
Field yields (nominator):
      / \ / \ / \     
     | 3 | 3 | 5 |    
    / \ / \ / \ / \   
   | 4 | 3 | 3 | 1 |  
  / \ / \ / \ / \ / \ 
 | 2 | 4 | 3 | 4 | 5 |
  \ / \ / \ / \ / \ / 
   | 4 | 2 | 5 | 2 |  
    \ / \ / \ / \ /   
     | 5 | 1 | 2 |    
      \ / \ / \ /     
 ```
