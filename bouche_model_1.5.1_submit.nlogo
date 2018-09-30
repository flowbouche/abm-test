;;_____________________________________________________________________________________________________________________________
;; PROGRAM
;;_____________________________________________________________________________________________________________________________

;; INITIALIZATION
;; Global properties
globals [
  time-step      ;; amount of "real-world" time that passes with every tick (affects aging and inoculum viability in dead hosts)

  ;; Monitors
  count-uninfected-trees                 ;; count of uninfected trees
  count-infected-trees                   ;; count of infected trees
  count-live-trees                       ;; count of live trees
  count-dead-trees                       ;; count of dead trees
  count-total-trees                      ;; count of total trees
  count-empty-patches                    ;; count of empty patches
  ; infection centers                    ;; count neighbors within a certain distance, infection center threshold TBD

  ;; Colors
  vector-col      carrier-col      ;; vector colors (non-carrier, carrier)
  tree-col        inf-tree-col     ;; Live trees: non-infected, infected
  dead-tree-col   dead-inf-col     ;; dead trees: non-infected, infected
  empty-col                        ;; empty patches
]

;; Agent properties
patches-own [
  age                              ;; float   :: Age of the tree (years) (empty patches have age = 0)
  tree                             ;; boolean :: occupied by tree (alive or dead) = true, empty = false
  alive                            ;; boolean :: Alive = true , dead or empty = false
  infected                         ;; boolean :: BSRD infected = true, non-infected or empty = false
  inf-countdown                    ;; float   :: time before dead trees lose viable inoculum
  inf-source                       ;; string  :: cause of infection: "vector" "root" "initial" or "NA"
]

turtles-own [ carrier ]            ;; boolean :: carrier or non-carrier of BSRD

to startup ;; set parameter values to initial configuration when the model is opened
  set-initial-config
end

;;_____________________________________________________________________________________________________________________________

;; MODEL SETUP
to setup
  ca ;; clear all

  set-time-step                          ;; set time step for each tick

  ;; SET UP FOREST LANDSCAPE (PATCHES)
  ;; Set world white, set default property values for empty spaces
  ask patches [
    set pcolor empty-col                 ;; set all white
    set tree false                       ;; set all to non-tree
    set alive false                      ;; set all as alive "NA"
    set infected false                   ;; set all as uninfected
    set age -1                           ;; set negative age
    set inf-countdown 0.0                ;; set countdown
    set inf-source "NA"                  ;; set infection source
  ]

  ;; Checker vs. random pattern
  ifelse checker? [
    ;; IF checker? is true
    ;; sets every other patch to live, uninfected tree by checking if remainder = 0 when coord value / 2
    ask patches [
      if (pxcor + pycor) mod 2 = 0 [
        set tree true
        set alive true
        set infected false
        set age initial-stand-age
      ]
    ;; set some percent as infected as set by slider
    ask patches with [ tree AND alive AND (random-float 100 <= infection-density)] [
        set infected true
        set inf-source "initial"
      ]
    ]
  ]
  ;; ELSE random pattern
  [
    ;; create live trees at percent as set by slider
    ask patches with [(random-float 1) <= tree-density] [
      set tree true
      set alive true
      set infected false
      set age initial-stand-age
    ]
    ;; set some percent as infected as set by slider
    ask patches with [ tree AND alive AND (random-float 1 <= infection-density)] [
      set infected true
      set inf-source "initial"
    ]
  ]

  ;; TURTLES: Create and set up vectors
  crt num-vectors [ ;; create turtles, number set by VECTORS slider
    setxy random-xcor random-ycor ;; place them randomly
    set shape "bug" ;; look like bugs
    set size 1 ;; size may be adjusted with patch size
    ifelse (random-float 1.0 <= pct-initial-carriers ) [
      set carrier true
    ]
    [ set carrier false ]
  ]

  set-colors                             ;; set colors
  color-world ;; set all of the colors in the world

  set-globals ;; calculate and set the value of the globals

  reset-ticks ;; set tick counter back to 0

  if attraction? [ print "Vector attraction is very much in beta..." ]

  check-setup
end

to set-time-step
  set time-step 0.1
end

to set-colors
  set  vector-col                    0  ;; non-carrier vectors
  set  carrier-col                 red  ;; carrier vectors
  set  tree-col                     62  ;; non-infected trees
  set  inf-tree-col                 45  ;; infected trees
  set  dead-tree-col                33  ;; dead, non-infected trees
  set  dead-inf-col                122  ;; dead, infected trees
  set  empty-col                 white  ;; empty patches
end

to color-world
  ;; color patches
  ask patches [
    if ( tree AND alive AND not infected )     [ set pcolor tree-col ]
    if ( tree AND alive AND infected )         [ set pcolor inf-tree-col ]
    if ( tree AND not alive AND not infected ) [ set pcolor dead-tree-col ]
    if ( tree AND not alive AND infected )     [ set pcolor dead-inf-col ]
    if not tree [ set pcolor empty-col ]
  ]
  ;; color turtles
  ask turtles [
    ifelse carrier = false [ set color vector-col ]
    [ set color carrier-col ]
  ]
end

to set-globals
  ;; GLOBAL MONITORS
  set count-uninfected-trees count patches with [ tree AND not infected ] ;; count of uninfected trees
  set count-infected-trees   count patches with [ tree AND infected ]     ;; count of infected trees
  set count-live-trees       count patches with [ tree AND alive ]        ;; count of live trees
  set count-dead-trees       count patches with [ tree AND not alive ]    ;; count of dead trees
  set count-total-trees      count patches with [ tree ]                  ;; count of total trees
  set count-empty-patches    count patches with [ not tree ]              ;; count of empty patches
end

to set-initial-config ;; set the default values for the sliders, switches etc.
  ;; landscape
  set checker?                 false
  set tree-density              0.80
  set infection-density         0.01
  set initial-stand-age         5.00
  set fungal-viability          0.50
  ;; vectors
  set num-vectors              10.00
  set dispersal-distance        3.00
  set pct-initial-carriers      0.00
  set prob-spore-attach         0.05
  set prob-vector-infection     0.50
  set attraction?              false
  set prob-root-spread          0.10
  set root-infection-radius     2.00
  ;; management
  set thinning?                false
  set thin-age                 15.00
  set pct-thin                  0.25
  set harvest?                 false
  set harvest-age              50.00
  set replant?                 false
  ;; general
  set stop?                     true
end

;;_____________________________________________________________________________________________________________________________
;; GO process
to go
  ;; END THE MODEL:
  ;; Once there are no more unincted trees, stop the model run.
  if stop? [
    if ( count-uninfected-trees = 0 ) [
      user-message "Black stain has inherited the earth."
      stop
    ]
    ;; Once there are no more infected trees and no more carrier vectors (no possibility for future infection)
    if ( count-infected-trees = 0 and not any? turtles with [ carrier ] ) [
      user-message "Black stain has been eradicated!"
      stop
    ]
    ;; Once there are no more live trees and none will be replanted
    if ( count-live-trees = 0 and not replant? ) [
      user-message "All the trees are dead!"
      stop
    ]
  ]

  ;; UPDATE
  aging ;; Increase tree age at each tick

  check-fungal-viability-in-dead-trees

  ;; MANAGEMENT
  ;; Simulate replanting
  replant
  ;; Simulate thinning
  thin
  ;; Simulate harvest
  harvest

  ;; INFECTION
  vector-infection
  root-infection

  ;; RESET ALL COLORS
  color-world
  ;; RESET GLOBAL MONITORS
  set-globals

  tick ;; end of go loop
end

;;_____________________________________________________________________________________________________________________________
;; PROCESSES

;; AGING PROCESS
to aging
  ask patches with [ tree ] [set age ( age + time-step ) ]
end

to check-fungal-viability-in-dead-trees
  ;; Make sure uninfected trees have "inf-source = NA"
  ask patches with [ tree AND not infected ] [ set inf-source "NA" ]

  ;; once the inf-countdown property of an infected tree reaches 0, that tree becomes uninfected
  ;; this reflects the fact that, in the real world, fungi in dead trees loses the ability to infect new trees over time
  ask patches with [ tree AND not alive AND infected ] [
    set inf-countdown (inf-countdown - time-step)
    if ( inf-countdown <= 0.0 ) [
      set infected false
      set inf-countdown 0.0
    ]
  ]
end

;; VECTOR INFECTION: Process of vector-mediated infection spread
to vector-infection
  ask turtles [
    ;; 1) MOVE VECTORS
    ifelse attraction? [ vector-attraction ];; In BETA
    [
    lt random 361 ;; random rotation
    fd random dispersal-distance ;; forward random amount < dispersal distance
    ]
    ;; 2) INFECT TREES: if the patch is uninfected tree and vector is carrier, then infect tree
    if ( not infected AND carrier AND ( random-float 1.0 <= prob-vector-infection ) ) [
      set infected true
      if inf-source = "NA" [ set inf-source "vector" ]
    ]
    ;; 3) INFEST VECTORS: If vector is on infected tree, change status to carrier
    if ( infected AND random-float 1.0 <= prob-spore-attach ) [
      set carrier true
    ]
  ]
end

;; ROOT INFECTION: Process of root-mediated infection: have radial growth, infection of trees within a certain radius.
to root-infection
  ask patches with [ alive AND infected ] [
    if random-float 1 <= prob-root-spread [
      ask one-of patches in-radius root-infection-radius [
        set infected true
        if inf-source = "NA" [ set inf-source "root" ]
      ]
    ]
  ]
end

;; ____ MANAGEMENT PROCESSES _____
;; THINNING: Kill a proportion of trees (based on % thinning slider) based on age (thinning age slider)
to thin
  if thinning? [
    ask patches with [ tree AND alive AND age >= thin-age AND age < ( thin-age + 0.1 ) ] [
      if random-float 1.0 <= pct-thin [
        set age 0 set alive false
        if not infected [
          set pcolor dead-tree-col
        ]
        if infected [
          set pcolor dead-inf-col
          set inf-countdown fungal-viability
        ]
      ]
    ]
  ]
end

;; HARVEST: Kill trees based on their age
to harvest
  if harvest? [
    ask patches with [ tree AND alive AND age >= harvest-age ] [
      set age 0
      set alive false
      if not infected [
        set pcolor dead-tree-col
      ]
      if infected [
        set pcolor dead-inf-col
        set inf-countdown fungal-viability
      ]
    ]
  ]
end

;; REPLANT: Replace dead trees with new, live trees
to replant
  ; When there are no living trees
  if replant? AND not any? patches with [ tree AND alive ] [
    ; create live trees
    ask patches with [ tree AND not alive ] [
      set alive true
      set age 0
      ; if the tree previously occupying the spot was infected,
      ; there's a 50% probability it will remain infected
      if infected AND random 2 = 1 [
        set infected false
      ]
    ]
  ]
end


;;_____________________________________________________________________________________________________________________________
;; TESTS
to check-setup
	let actual-pct-trees ( count patches with [ tree ] / count patches )
	ifelse actual-pct-trees < 0.9 * tree-density OR actual-pct-trees > 1.1 * tree-density [
		print "Difference in initial trees is greater than 10%."
	]
  [ print "Tree setup successful." ]

  let actual-pct-inf-trees ( count patches with [ tree and infected ] / count patches with [ tree ] )
	ifelse actual-pct-inf-trees < 0.9 * infection-density OR actual-pct-inf-trees > 1.1 * infection-density [
		print "Difference in initial infected trees is greater than 10%."
    print "This is hard to avoid with this world size and initial infection density"
	]
  [ print "Initial infection setup successful." ]

end

;;_____________________________________________________________________________________________________________________________
;; Testing still...
;;_____________________________________________________________________________________________________________________________
to vector-attraction
  ;; creates an agentset of patches for this
  let attraction-cone ( patch-set
    patch-ahead 1
    patch-ahead 2
    patch-left-and-ahead 45 1
    patch-left-and-ahead 45 2
    patch-left-and-ahead 90 1
    patch-left-and-ahead 90 2
    patch-right-and-ahead 45 1
    patch-right-and-ahead 45 2
    patch-right-and-ahead 90 1
    patch-right-and-ahead 90 2
  )
  let attractors attraction-cone with [ infected ]
  ifelse attractors != no-patches [ move-to one-of attractors ]
  [
  lt random 361 ;; random rotation
  fd random dispersal-distance ;; forward random amount < dispersal distance
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
301
23
850
573
-1
-1
28.5
1
10
1
1
1
0
0
0
1
-9
9
-9
9
1
1
1
ticks
30.0

BUTTON
20
588
98
622
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
190
590
280
623
go forever
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
134
144
285
177
num-vectors
num-vectors
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
134
22
286
55
tree-density
tree-density
0
1.0
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
134
58
286
91
infection-density
infection-density
0
1.0
0.01
0.01
1
NIL
HORIZONTAL

MONITOR
321
579
387
624
Uninfected
count-uninfected-trees
0
1
11

MONITOR
390
579
454
624
Infected
count-infected-trees
0
1
11

MONITOR
457
579
519
624
Trees
count-total-trees
0
1
11

MONITOR
523
579
582
624
Empty
count-empty-patches
0
1
11

SLIDER
136
220
286
253
dispersal-distance
dispersal-distance
0
100
3.0
1
1
NIL
HORIZONTAL

SWITCH
14
500
118
533
harvest?
harvest?
1
1
-1000

MONITOR
586
579
668
624
Mean live age
mean [ age ] of patches with [ tree and alive ]
2
1
11

SLIDER
135
95
286
128
initial-stand-age
initial-stand-age
0
200
5.0
1
1
yr
HORIZONTAL

SWITCH
13
460
118
493
thinning?
thinning?
1
1
-1000

SLIDER
131
420
295
453
thin-age
thin-age
0
100
15.0
1
1
yr
HORIZONTAL

SLIDER
131
459
295
492
pct-thin
pct-thin
0
1
0.25
0.05
1
NIL
HORIZONTAL

SLIDER
130
498
295
531
harvest-age
harvest-age
0
100
50.0
1
1
yr
HORIZONTAL

SWITCH
3
21
118
54
checker?
checker?
1
1
-1000

SLIDER
136
182
287
215
pct-initial-carriers
pct-initial-carriers
0
1.0
0.0
0.01
1
NIL
HORIZONTAL

MONITOR
769
579
833
624
Carriers
count turtles with [ carrier ]
1
1
11

BUTTON
106
589
181
622
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
134
299
286
332
prob-vector-infection
prob-vector-infection
0
1.0
0.5
0.01
1
NIL
HORIZONTAL

SWITCH
15
419
118
452
replant?
replant?
1
1
-1000

SWITCH
15
543
118
576
stop?
stop?
0
1
-1000

SLIDER
133
258
287
291
prob-spore-attach
prob-spore-attach
0
1.0
0.05
0.01
1
NIL
HORIZONTAL

BUTTON
133
542
281
575
Default configuration
set-initial-config
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
859
23
1252
384
Infected trees, infested vectors
Ticks
%
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"% vectors inf." 1.0 0 -5298144 true "" "plot ( ( count turtles with [ carrier ] ) / count turtles ) * 100"
"% trees inf." 1.0 0 -16777216 true "" "plot (count-infected-trees / count-total-trees) * 100"

PLOT
863
402
1253
627
Age of live trees (Histogram)
age (yr)
count
0.0
2.0
0.0
10.0
false
false
"" "set-plot-y-range 0 count-total-trees\nset-plot-x-range 0 harvest-age"
PENS
"live trees" 1.0 1 -15575016 true "" "histogram [age] of patches with [ alive ]"

SLIDER
1
58
129
91
fungal-viability
fungal-viability
0
2
0.5
0.05
1
yr
HORIZONTAL

MONITOR
674
579
762
624
Mean dead age
mean [ age ] of patches with [ tree and not alive ]
2
1
11

SWITCH
13
222
129
255
attraction?
attraction?
1
1
-1000

SLIDER
134
338
286
371
root-infection-radius
root-infection-radius
0
5
2.0
1
1
NIL
HORIZONTAL

SLIDER
133
377
287
410
prob-root-spread
prob-root-spread
0
1.0
0.1
0.01
1
NIL
HORIZONTAL

PLOT
1261
26
1665
384
Infection source
ticks
% trees infected
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"root" 1.0 0 -8431303 true "" "plot ( count patches with [ inf-source = \"root\" ] ) / ( count patches with [ infected ] )"
"vector" 1.0 0 -5298144 true "" "plot (count patches with [inf-source = \"vector\" ])/ ( count patches with [ infected ] )"
"initial" 1.0 0 -16777216 true "" "plot (count patches with [inf-source = \"initial\" ]) / ( count patches with [ infected ] )"

@#$#@#$#@
## WHAT IS IT?

This is a model of root disease spread between trees in the landscape. The disease spreads via two transmission processes: (a) root contact/root graft transmission between adjacent trees and (b) insect vectors that carry spores between trees.

## HOW IT WORKS

This model has a large number of variations designed to test the nature of the system under different conditions and thus explore hypotheses.

### Agents
#### Patches
Each patch represent the space for one tree. The identity of that patch is indicated by the color and properties, including tree (true/false), alive (true/false), infected (true/false), and "inf-source" (the cause of the infection, either "initial" from the SETUP, "vector", "root" from root spread, or "NA" for uninfected trees).

This disease is seeded into the landscape at a user-defined proportion of all patche and then spreads between adjacent trees via root systems and when carried by insect vectors.

Each patch represents a tree or an empty space where a tree could be. Each tree is either alive or dead, whole or a stump, infected or not infected. Trees also have an age, which is updated at each tick. Finally, trees have an "infection countdown" property, discussed later.

>**Patch colors:**
>  * **Live, uninfected tree:** Green
>  * **Live, infected tree:** Yellow
>  * **Dead, uninfected tree/stump:** Brown
>  * **Dead, infected tree/stump:** Dark red/maroon
>  * **Empty space:** White

#### Turtles
Each turtle (bug-shaped agent) represents an insect vector. The vector has only one property: carrier (true/false), which indicates if the insect carries the disease or not and thus whether it can infect new trees. The number of turtles remains constant throughout the model, and no new turtles are born or die.
>**Patch colors:**
>  * **Non-carrier:** Black
>  * **Carrier:** Red

### STARTUP
Upon opening the model, all user-defined parameters are set to default values as determined by the "set-initial-config" procedure. If parameter values are changed by the user, the "Default configuration" button can be used to reset parameters to these default values.

### SETUP
  1. The model is cleared, the time set represented by each tick is set, and the properties of all patches are set to empty space values.
  2. Patches are set to create live trees, either placed in a checker-board pattern if the "checker?" switch is set to "on" (always the same number of trees) or randomly at the proportion indicated by the "tree-density" slider.
    A. All trees are set to the same age, as determined by the "initial-stand-age" slider.
    B. Some proportion of the trees are set to infected, based on the "infection-density" slider.
  3. A number of insect vectors (turtles) are created according to the "num-vectors". Some proportion of the vectors are set as carriers as determined by the "pct-initial-carriers" slider if the "carriers?" switch is set to "on".
  4. Default colors are set and the "world" is colored.
  5. Counts are set as globals and (some) are displayed in the monitors (total # of trees, # of live trees, # of dead trees, # of uninfected trees, # of infected trees, # of empty patches).
  6. Tick count is reset to 0.

### GO (iterative/tick):
  **1. STOP PROCEDURE:** If there are no more live, uninfected trees, the model stops and returns the message, "Black stain has inherited the earth."
Similarly, if there are no more infected trees and no disease-carrying vectors, the model stops and returns the message,
"Black stain has been eradicated!" If there are no live trees and the "replant?" switch is off, the model stops and returns the message,
"All the trees are gone!"

  **2. AGING:** Each tree's age increases by the value "time-step".

  **3. CHECK FUNGAL VIABILITY:** Fungal viability is checked in dead trees. Once an infected tree dies, the "inf-countdown" property is set to the value of the "fungal-viability" slider. The dead tree will remain infected for as long as the value of "inf-countdown" is greater than 0. If it is less than or equal to 0, the dead, infected tree will become uninfected.  This reflects the fact that, in the real world, fungi in dead trees loses the ability to infect new trees over time.

  **4. REPLANTING:** Replanting occurs (dead trees set to alive and age reset) if "replant?" swtich is set to "on". All dead trees are set to alive and their age is set to 0. Roughly half of dead, infected trees will be replanted as already infected because the root disease pathogen can linger alive in the soil. Trees are always replanted in the same spot in this model version, with empty cells forever remaining empty.

  **5. THINNING:** Thinning occurs if the "thinning?" switch is on. Some percentage of trees ("pct-thin" slider) at the user defined thinning age ("thin-age" slider) will be killed and have their age set to 0. For dead, infected trees, the fungal viability countdown begins.

  **6. HARVEST:** Harvest occurs if the "harvest?" switch is on. All trees ("pct-thin" slider) at the user defined harvest age ("harvest-age" slider) will be killed and have their age set to 0. For dead, infected trees, the fungal viability countdown begins.

  **7. VECTOR INFECTION:** - Trees are infected via vectors. This consists of three steps outlined in the "vector-infection" procedure:
    **7A. Vectors move:**
    **i.** If the "attraction?" switch is ON, an attraction cone is created for each vector, consisting of a set of infected patches: 1 and 2 ahead, left 45 degrees and 1 and 2 ahead, left 90 degrees and 1 and 2 ahead, right 45 degrees and 1 and 2 ahead, and right 90 degrees and 1 and 2 ahead. If there are infected patches in this attraction-cone, the vector moves to one of those patches. If there are no infected patches in this attraction cone, the vector turns to a random direction (0 to 360 degrees) and moves forward as determined by the "dispersal-distance" slider.
    **ii.** If the "attraction?" switch is OFF, the vector turns to a random direction (0 to 360 degrees) and moves forward as determined by the "dispersal-distance" slider.
    **7B. Infect:** Vectors can infect trees if the vector is a carrier. The probability of this occurring is based on the "prob-vector-infection" slider.
    **7C. Infest:** Vectors can become carriers if they are on a patch that is an infected tree. The probability of this occurring is based on the "prob-spore-attach" slider.

  **8. ROOT INFECTION:** - Live, infected trees can infect one of the patches at a certain distance from them (based on "root-infection-radius" slider). The probability that this occurs is based on the "prob-root-spread" slider. This represents the real-world process of fungal growth between adjacent trees with very close or connected root systems.

  **9. COLOR WORLD:** The colors of the patches and turtles are updated to reflect their properties.

  **10. SET GLOBALS:** The globals, including counts of patches with particular characteristics, are updated to reflect the current state of the world.


## HOW TO USE IT

Choose initial parameter settings using the sliders and switches or select the default configuration using the button.
>**INPUTS:**

>_**GENERAL**_
>_**stop?**_ - Whether or not the model will stop on its own given certain states of the world. If OFF, the model will run forever regardless of the state of the world.

>_**WORLD**_
>_**checker?**_ - When ON, sets the initial forest to a checkerboard pattern (ignores "tree-density" slider)
>_**tree-density**_ - The proportion of patches that are trees (rather than empty spaces)
>_**infection-density**_ - The initial proportion of trees that are infected
>_**initial-stand-age**_ - The initial age of all trees in the world
>_**num-vectors**_ - Sets the number of vectors (turtles) present. This does not change throughout the model run.
>_**pct-initial-carriers**_ - Sets the number of vectors that are carriers after running the SETUP.

>_**VECTORS**_
>_**attraction?**_ - Determines whether vectors move to infected trees in their immediate viscinity rather than following the normal move procedure.
>_**dispersal-distance**_ - The distance that each vector moves at each tick. The only exception to this is when the "attraction?" switch is ON.
>_**prob-spore-attach**_ - The probability that a non-carrier vector will become a carrier when it is at an infected tree patch.
>_**prob-vector-infection**_ - The probability that a non-infected tree will become infected when a carrier vector is present.

>_**TREES**_
>_**root-infection-radius**_ - The maximum distance that an infected tree can infect another via root spreading.
>_**prob-root-spread**_ - The probability that the infection will spread via the "root-infection" procedure for each patch at every time step.

>_**MANAGEMENT**_
>_**replant?**_ - Whether dead trees are replanted after a harvest.
>_**thinning?**_ - Whether or not the thinning procedure will run.
>_**thin-age**_ - The age at which the thinning procedure will be applied, if "thinning?" is ON.
>_**pct-thin**_ - The proportion of live trees that will be killed when the thinning procedure runs.
>_**harvest?**_ - Whether or not the harvest procedure will run.
>_**harvest-age**_ - The age at which trees will be harvested (killed).

Click SETUP to create the forest and the vectors.

Click GO ONCE (one tick) or GO FOREVER to start the simulation.

Note that some parameter settings will not take effect until the next SETUP.

Outputs of particular interest given initial conditions include:
  * Percent of trees infected over time
  * Relative amount of infection from root vs. vector infection (see infection source plot)
  * Amount of carriers
  * Time to full infection
  * Time to disease eradication

## THINGS TO NOTICE

What conditions lead to root infection being the dominant mechanism of disease spread? What conditions lead to vectors being the dominant mechanism of disease spread?

What management conditions (e.g. thinning, harvest, age of management actions, percent of forest thinned) lead to disease eradication versus the entire forest becoming infected?

## THINGS TO TRY

Play around!

## EXTENDING THE MODEL

  * Setting maximum dispersal, stochastic dispersal
  * Dead trees can become infected for some limited amount of time
  * Changing number of vectors (generations)

## NETLOGO FEATURES

Uses "neighbors", "in-radius", and other unique commands.

## RELATED MODELS

Fire, Spread of Disease

## CREDITS AND REFERENCES

Adam Bouché is the sole author of this model. References for code were taken from experience playing with other models in the NetLogo library and in the Intro to Agent-based Modeling textbook by Wilensky and Rand.

## COPYRIGHT AND LICENSE
Though no formal copyright or license yet exists, Adam Bouché (the author) intends to pursue a Creative Commons License.

## ACKNOWLEDGEMENTS
Thank you to Bill Rand for teaching this course on NetLogo and Agent-Based Modeling and Uri Wilensky for creating and contributing to NetLogo.

Thank you to my professors for helping in the development of this project and the conceptual model on which this model is based.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
