# HealBot

## Mashup between Original and Updated Versions as of 12/15/2021

## Original:
### https://github.com/lorand-ffxi/HealBot

## Additions:
### https://github.com/KateFFXI/HealBot (Updated 09/22/2021)
### https://github.com/AkadenTK/HealBot (Updated 05/21/2019)

## Update: HealBot now depends on [libs/lor](https://github.com/lorand-ffxi/lor_libs)

## NEW: IPC has been added! (see below)

### Summary

By default, HealBot will monitor the party that it is in.  Commands to monitor
or ignore additional players can be found below.

Buffs gained via job abilities are now supported, but have not yet been tested
extensively.  Composure has been confirmed to work.  With the addition of job
ability support comes support for prioritization (since, for example, Composure
should be used before other buffs are applied).

Detection of whether the local healer is able to act has been improved for when
debuffs such as sleep or petrify are active, so that now it should not try to
spam spells while unable to act.  This is apparent by the text box in the top-
left corner of the screen displaying the message 'Player is disabled'.

Bard songs are officially unsupported at this time.  YMMV - it cannot handle the
fact that there is no notification given when one song overwrites another, or
maintaining multiple buffs that have the same name.  That being said, if you
only want to maintain 2-3 songs without using a dummy song, it may work.  I have
an idea about how to support BRD songs, so that should be coming soon.

Also coming soon is the ability to cast offensive spells on an assist target's
target.

--------------------------------------------------------------------------------

### IPC (Inter-Process Communication)

HealBot now supports IPC between multiple instances of Windower running on the
same computer when both characters have HealBot loaded!  This means that HealBot
will now be even better at detecting the buffs/debuffs that are active for
characters on the same computer!

Only the healer's HealBot needs to be on - the non-healer just needs to have
HealBot loaded to be able to tell the healer's instance about its active buffs
and debuffs.


### Settings

If you have the shortcuts addon installed, your aliases.xml file from that addon
will be loaded, and those aliases will be available for use when specifying
buffs.

You can edit/add/remove buff lists that can be invoked with the
`//hb bufflist listName targetName` command in data/buffLists.xml.  The order of
buffs within the list does not affect the order in which they will be cast.
Follow the syntax of existing sets when adding/editing your own.

You can modify the priority with which other players will be attended to by
editing data/priorities.xml.  Note that detection of players' jobs is not
perfect at the moment, so it is better to specify individual players' priorities
by name.  Lower numbers represent higher priority.  Follow the syntax of
existing sets when adding/editing your own.

Monster abilities that do not display what debuffs they cause are specified in
mabil_debuffs.xml.  This list is woefully incomplete, but I plan on vastly
expanding it in the near future.  If you decide to add any, I would greatly
appreciate it if you would share what you have added.  If you add something, and
it isn't detected, please notify me, and I will attempt to make sure that it can
be detected in the future.

Place the healBot folder in .../Windower/addons/

* To load healBot: `//lua load healbot`
* To unload healBot: `//hb unload`
* To reload healBot: `//hb reload`

### Command List

#### General Setup Commands
| Command                                | Action                                                                                                        |
| ---------------------------------------| --------------------------------------------------------------------------------------------------------------|
| //hb on                                | Activate                                                                                                      |
| //hb off                               | Deactivate (note: follow will remain active)                                                                  |
| //hb refresh                           | Reload settings xmls in the data folder                                                                       |
| //hb status                            | Displays whether or not healBot is active in the chat log                                                     |
| //hb mincure (#)                       | Set the minimum cure tier to # (default is 3 - if this is spammy set it to 4 to be safe)                      |
| //hb independent (on | off)            | Sets it as independent player use and continues any of the automation - autoassist and follow should be off   |

#### Healing / Curing
| Command                                         | Action                                                                                               |
| ------------------------------------------------| -----------------------------------------------------------------------------------------------------|
| //hb ignore (charName)                          | Ignore player charName so they won't be healed                                                       |
| //hb unignore (charName)                        | Stop ignoring player charName (note: will not watch a player that would not otherwise be watched)    |
| //hb disable (actionType)                       | Disables actions of a given type (cure, buff, na)                                                    |
| //hb enable (actionType)                        | Enables actions of a given type (cure, buff, na)                                                     |
| //hb disable (actionType)                       | Disables actions of a given type (cure, buff, na)                                                    |
| //hb ignore_debuff (player/always) (debuff)     | Ignores when the given debuff is cast on the given player or everyone                                |
| //hb unignore_debuff (player/always) (debuff)   | Stops ignoring when the given debuff is cast on the given player or everyone                         |
| //hb watch (charName)                           | Watch player charName so they will be healed                                                         |
| //hb unwatch (charName)                         | Stop watching player charName (note: will not ignore a player that would be otherwise watched)       |
| //hb ignoretrusts on                            | Ignore Trust NPCs (default)                                                                          |
| //hb ignoretrusts off                           | Heal Trust NPCs                                                                                      |

#### Buffs and Debuffs
| Command                                | Action                                                                                                    |
| ---------------------------------------| ----------------------------------------------------------------------------------------------------------|
| //hb reset                             | Reset buff & debuff monitors                                                                              |
| //hb reset buffs                       | Reset buff monitors                                                                                       |
| //hb reset debuffs                     | Reset debuff monitors                                                                                     |
| //hb buff charName spellName           | Maintain the buff spellName on player charName                                                            |
| //hb buff (t) spellName                | Maintain the buff spellName on current target                                                             |
| //hb cancelbuff charName spellName     | Stop maintaining the buff spellName on player charName                                                    |
| //hb cancelbuff (t) spellName          | Stop maintaining the buff spellName on current target                                                     |
| //hb bufflist listName charName        | Maintain the buffs in the given list of buffs on player charName                                          |
| //hb bl listName charName              | Maintain the buffs in the given list of buffs on player charName (bufflist shorthand)                     |
| //hb bufflist listName (t)             | Maintain the buffs in the given list of buffs on current target                                           |
| //hb debuff spellName                  | Maintain the debuff spellName on assisted target                                                          |
| //hb debuff rm spellName               | Removes from the list of the debuffs on assisted target                                                   |
| //hb debuff on                         | Auto debuffs on assisted target from set list                                                             |
| //hb debuff off                        | Stops auto debuffs on assisted target                                                                     |
| //hb debuff ls                         | Lists Auto debuffs on assisted target                                                                     |
| //hb db spellName                      | Maintain the debuff spellName on assisted target (shorthand for debuff)                                   |
| //hb db rm spellName                   | Removes from the list of the debuffs on assisted target (shorthand for debuff)                            |
| //hb db on                             | Auto debuffs on assisted target from set list (shorthand for debuff)                                      |
| //hb db off                            | Stops auto debuffs on assisted target (shorthand for debuff)                                              |
| //hb db ls                             | Lists Auto debuffs on assisted target (shorthand for debuff)                                              |

#### Auto Assist
| Command                            | Action                                                                                                        |
| -----------------------------------| --------------------------------------------------------------------------------------------------------------|
| //hb assist (charName)             | Assists player charName (This Must be in proper form - Fendo not fendo)                                       |
| //hb assist attack                 | Will engage target mob on assist                                                                              |
| //hb assist off                    | Stop assisting player                                                                                         |
| //hb assist resume                 | Resumes assisting                                                                                             |
| //hb as (charName)                 | Assists player charName (This Must be in proper form - Fendo not fendo) (assist shorthand)                    |
| //hb as attack                     | Will engage target mob on assist (assist shorthand)                                                           |
| //hb as off                        | Stop assisting player (assist shorthand)                                                                      |
| //hb as resume                     | Resumes assisting (assist shorthand)                                                                          |


#### Auto Follow
| Command                            | Action                                                                                                        |
| -----------------------------------| --------------------------------------------------------------------------------------------------------------|
| //hb follow (charName)             | Follow player charName                                                                                        |
| //hb follow (t)                    | Follow current target                                                                                         |
| //hb follow off                    | Stop following                                                                                                |
| //hb follow resume                 | Resumes following                                                                                             |
| //hb follow dist (#)               | Set the follow distance to #                                                                                  |
| //hb f (charName)                  | Follow player charName (follow shorthand)                                                                     |
| //hb f (t)                         | Follow current target (follow shorthand)                                                                      |
| //hb f off                         | Stop following (follow shorthand)                                                                             |
| //hb f resume                      | Resumes following (follow shorthand)                                                                          |
| //hb f dist (#)                    | Set the follow distance to # (follow shorthand)                                                               |

#### Weapon Skills
| Command                                | Action                                                                                                        |
| ---------------------------------------| --------------------------------------------------------------------------------------------------------------|
| //hb weaponskill use (ws name)         | Selects weaponskill to use                                                                                    |
| //hb weaponskill tp (number 1000-2999) | Selects min tp for a weaponskill                                                                              |
| //hb weaponskill hp (sign) (mob hp%)   | Sets the mob HP for weaponskill use (example < 100  or > 1)                                                   |
| //hb weaponskill waitfor (player) (tp) | Waits for another player to use weaponskill at a certain TP                                                   |
| //hb weaponskill nopartner             | Does not wait for another player to use weaponskill tain TP                                                   |
| //hb ws use (ws name)                  | Selects weaponskill to use (weaponskill shorthand)                                                            |
| //hb ws tp (number 1000-2999)          | Selects min tp for a weaponskill (weaponskill shorthand)                                                      |
| //hb ws hp (sign) (mob hp%)            | Sets the mob HP for weaponskill use (example < 100  or > 1) (weaponskill shorthand)                           |
| //hb ws waitfor (player) (tp)          | Waits for another player to use weaponskill at a certain TP (weaponskill shorthand)                           |
| //hb ws nopartner                      | Does not wait for another player to use weaponskill tain TP (weaponskill shorthand)                           |

#### Debugging Commands
| Command                                | Action                                                                                                        |
| ---------------------------------------| --------------------------------------------------------------------------------------------------------------|
| //hb moveinfo on                       | Will display current (x,y,z) position and the amount of time spent at that location in the upper left corner. |
| //hb moveinfo off                      | Hides the moveInfo display                                                                                    |
| //hb packetinfo on                     | Adds to the chat log packet info about monitored players                                                      |
| //hb packetinfo off                    | Prevents packet info from being added to the chat log                                                         |

