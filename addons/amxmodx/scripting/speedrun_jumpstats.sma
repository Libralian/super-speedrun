#define UNLIMITED_GRAVITY_AND_AA

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <engine>
#include <q_jumpstats_const>
#include <q_message>
#include <speedrun>

#pragma semicolon 1

#define PLUGIN "Speedrun Jump Stats"
#define VERSION "1.0"
#define AUTHOR "Lopol2010"
#define PLUGIN_TAG "LJStats"

#define TASKID_SPEED 489273421

#define LJSTATS_MENU_ID "LJ Stats Menu"

enum State
{
    State_Initial,
    State_InJump_FirstFrame,
    State_InJump,
    State_InDD_FirstFrame,
    State_InDD,
    State_InDrop,		// fall below duck/jump origin while still in air
    State_InFall,		// walk across the edge of surface
    State_OnLadder,
    State_InLadderDrop,	// jump from ladder
    State_InLadderFall	// slide out of ladder
};

enum _:JUMPSTATS
{
    JUMPSTATS_ID[32],
    JUMPSTATS_NAME[32],
    Float:JUMPSTATS_DISTANCE,
    Float:JUMPSTATS_MAXSPEED,
    Float:JUMPSTATS_PRESTRAFE,
    JUMPSTATS_STRAFES,
    JUMPSTATS_SYNC,
    JUMPSTATS_TIMESTAMP,	// Date
}

new const FL_ONGROUND2 = FL_ONGROUND | FL_PARTIALGROUND | FL_INWATER | FL_CONVEYOR | FL_FLOAT;

// new sv_airaccelerate;
// new sv_gravity;

new air_touch[33];

new State:old_player_state[33];
new State:player_state[33];

new player_show_speed[33];
new player_show_stats[33];
new player_show_stats_chat[33];
new player_show_prestrafe[33];

new ducking[33];
new oldDucking[33];
new flags[33];
new oldflags[33];
new buttons[33];
new oldbuttons[33];
new movetype[33];

new Float:origin[33][3];
new Float:oldorigin[33][3];
new Float:velocity[33][3];
new Float:oldvelocity[33][3];
new Float:old_h2_injump[33];

new jump_start_ducking[33];
new Float:jump_start_origin[33][3];
new Float:jump_start_velocity[33][3];
new Float:jump_start_time[33];
new jump_end_ducking[33];
new Float:jump_end_origin[33][3];
new Float:jump_end_time[33];

new injump_started_downward[33];
new injump_frame[33];
new inertia_frames[33];
new obbo[33];

new Float:jump_first_origin[33][3];
new Float:jump_first_velocity[33][3];
new Float:jump_last_origin[33][3];
new Float:jump_last_velocity[33][3];
new Float:jump_fail_origin[33][3];
new Float:jump_fail_velocity[33][3];

new jump_turning[33];
new jump_strafing[33];

new JumpType:jump_type[33];
new Float:jump_distance[33];
new Float:jump_prestrafe[33];
new Float:jump_maxspeed[33];
new jump_sync[33];
new jump_frames[33];
new Float:jump_speed[33];
new Float:jump_angles[33][3];
new jump_strafes[33];
new jump_strafe_sync[33][MAX_STRAFES];
new jump_strafe_frames[33][MAX_STRAFES];
new Float:jump_strafe_gain[33][MAX_STRAFES];
new Float:jump_strafe_loss[33][MAX_STRAFES];

new dd_count[33];
new Float:dd_prestrafe[33][3]; // last three dds, not a vector
new Float:dd_start_origin[33][3];
new Float:dd_start_time[33];
new Float:dd_end_origin[33][3];
new Float:dd_end_time[33];

new Float:drop_origin[33][3];
new Float:drop_time[33];

new Float:fall_origin[33][3];
new Float:fall_time[33];

new Float:ladderdrop_origin[33][3];
new Float:ladderdrop_time[33];

new g_DisplaySimpleStats[33];
new g_DisplayLJStats[33];
new g_DisplayHJStats[33];
new g_DisplayCJStats[33];
new g_DisplayWJStats[33];
new g_DisplayBhStats[33];
new g_DisplayLadderStats[33];
new g_MuteJumpMessages[33];

new Trie:illegal_touch_entity_classes;

public plugin_init( )
{
    register_plugin( PLUGIN, VERSION, AUTHOR );
    
    // register_dictionary( "q_jumpstats.txt" );
    
    register_forward( FM_PlayerPreThink, "forward_PlayerPreThink" );
    RegisterHam( Ham_Spawn, "player", "forward_PlayerSpawn" );
    // RegisterHam( Ham_Touch, "player", "forward_PlayerTouch", 1 );
    // register_touch("trigger_push", "player", "forward_PushTouch");
    register_touch("trigger_teleport", "player", "forward_TeleportTouch");

    illegal_touch_entity_classes = TrieCreate( );
    TrieSetCell( illegal_touch_entity_classes, "func_train", 1 );
    TrieSetCell( illegal_touch_entity_classes, "func_door", 1 );
    TrieSetCell( illegal_touch_entity_classes, "func_door_rotating", 1 );
    TrieSetCell( illegal_touch_entity_classes, "func_conveyor", 1 );
    TrieSetCell( illegal_touch_entity_classes, "func_rotating", 1 );
    TrieSetCell( illegal_touch_entity_classes, "trigger_push", 1 );
    TrieSetCell( illegal_touch_entity_classes, "trigger_teleport", 1 );

    register_clcmd( "say /stats", "clcmd_ljstats" );
    register_clcmd( "say /ljstats", "clcmd_ljstats" );
    register_clcmd( "say /jumpstats", "clcmd_ljstats" );
    register_clcmd( "say /showpre", "clcmd_prestrafe" );
    register_clcmd( "say /preshow", "clcmd_prestrafe" );
    register_clcmd( "say /prestrafe", "clcmd_prestrafe" );

    register_menucmd(register_menuid(LJSTATS_MENU_ID), 1023, "actions_ljstats");
    
    // sv_airaccelerate = get_cvar_pointer( "sv_airaccelerate" );
    // sv_gravity = get_cvar_pointer( "sv_gravity" );
}

public client_connect( id )
{
    reset_state( id );
    
    player_show_speed[id] = false;
    player_show_stats[id] = true;
    player_show_stats_chat[id] = true;
    player_show_prestrafe[id] = false;
    g_DisplaySimpleStats[id] = false;
    g_DisplayLJStats[id] = false;
    g_DisplayHJStats[id] = false;
    g_DisplayCJStats[id] = false;
    g_DisplayWJStats[id] = false;
    g_DisplayBhStats[id] = false;
    g_DisplayLadderStats[id] = false;
    g_MuteJumpMessages[id] = false;
}

reset_state( id )
{
    old_player_state[id] = State_Initial;
    player_state[id] = State_Initial;
    injump_started_downward[id] = false;
    injump_frame[id] = 0;
    
    jump_start_time[id] = 0.0;
    jump_end_time[id] = 0.0;
    dd_start_time[id] = 0.0;
    dd_end_time[id] = 0.0;
    drop_time[id] = 0.0;
    fall_time[id] = 0.0;
    
    reset_stats( id );
}

reset_stats( id )
{
    injump_started_downward[id] = false;
    injump_frame[id] = 0;
    jump_turning[id] = 0;
    jump_strafing[id] = 0;
    
    jump_prestrafe[id] = 0.0;
    jump_maxspeed[id] = 0.0;
    jump_sync[id] = 0;
    jump_frames[id] = 0;
    for( new i = 0; i < sizeof(jump_strafe_sync[]); ++i )
    {
        jump_strafe_sync[id][i] = 0;
        jump_strafe_frames[id][i] = 0;
        jump_strafe_gain[id][i] = 0.0;
        jump_strafe_loss[id][i] = 0.0;
    }
    jump_strafes[id] = 0;
}

public clcmd_ljstats( id )
{

    g_DisplaySimpleStats[id] = !g_DisplaySimpleStats[id];
    client_print_color(id, print_team_default, "%s Jump stats %s!", PREFIX, g_DisplaySimpleStats[id] ? "enabled" : "disabled");
    // new menuBody[512], len;
    // new keys = MENU_KEY_0 | MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9;

    // len = formatex(menuBody[len], charsmax(menuBody), "%s^n^n", PLUGIN_TAG);
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "1. Top 15 Longjump / Highjump^n");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "2. Top 15 Countjump^n");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "3. Display Longjump stats: %s^n", g_DisplayLJStats[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "4. Display Highjump stats: %s^n", g_DisplayHJStats[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "5. Display Countjump stats: %s^n", g_DisplayCJStats[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "6. Display Weirdjump stats: %s^n", g_DisplayWJStats[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "7. Display Bhop stats: %s^n", g_DisplayBhStats[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "8. Display Ladder stats: %s^n", g_DisplayLadderStats[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "9. Mute LJStats jump messages of others: %s^n", g_MuteJumpMessages[id] ? "ON" : "OFF");
    // len += formatex(menuBody[len], charsmax(menuBody) - len, "0. Exit");

    // show_menu(id, keys, menuBody, -1, LJSTATS_MENU_ID);
    return PLUGIN_HANDLED;
}

public actions_ljstats(id, key)
{
    key++;
    switch (key)
    {
        case 0, 10: return PLUGIN_HANDLED;
        case 1: return PLUGIN_HANDLED;
        case 2: show_hudmessage(id, "Not implemented yet!");
        case 3: g_DisplayLJStats[id] = !g_DisplayLJStats[id];
        case 4: g_DisplayHJStats[id] = !g_DisplayHJStats[id];
        case 5: g_DisplayCJStats[id] = !g_DisplayCJStats[id];
        case 6: g_DisplayWJStats[id] = !g_DisplayWJStats[id];
        case 7: g_DisplayBhStats[id] = !g_DisplayBhStats[id];
        case 8: g_DisplayLadderStats[id] = !g_DisplayLadderStats[id];
        case 9: g_MuteJumpMessages[id] = !g_MuteJumpMessages[id];
    }

    clcmd_ljstats(id);
    return PLUGIN_HANDLED;
}

public clcmd_prestrafe( id, level, cid )
{
    player_show_prestrafe[id] = !player_show_prestrafe[id];
    client_print_color( id, print_team_default, "%s Prestrafe: %s", PREFIX, player_show_prestrafe[id] ? "ON" : "OFF" );
    
    return PLUGIN_HANDLED;
}

public forward_PlayerSpawn( id )
{
    reset_state( id );
}

public forward_PlayerTouch( id, other )
{
    static name[32];
    
    if( flags[id] & FL_ONGROUND2 )
    {
        pev( other, pev_classname, name, charsmax(name) );
        if( TrieKeyExists( illegal_touch_entity_classes, name ) )
            reset_state( id );
    }
    else
    {
        air_touch[id] = true;
    }
}

public forward_PushTouch ( ent, id )
{
    if (is_user_alive( id ))
        event_jump_illegal( id );
}

public forward_TeleportTouch ( ent, id )
{
    if (is_user_alive( id ))
        event_jump_illegal( id );
}

public forward_PlayerPreThink( id )
{
    flags[id] = pev( id, pev_flags );
    buttons[id] = pev( id, pev_button );
    pev( id, pev_origin, origin[id] );
    pev( id, pev_velocity, velocity[id] );
    movetype[id] = pev( id, pev_movetype );
    
    static Float:absmin[3];
    static Float:absmax[3];
    pev( id, pev_absmin, absmin );
    pev( id, pev_absmax, absmax );
    oldDucking[id] = ducking[id];
    ducking[id] = !( ( absmin[2] + 64.0 ) < absmax[2] );
    
    static Float:gravity;
    pev( id, pev_gravity, gravity );

    if (get_player_hspeed(id) <= 450.0)
        inertia_frames[id] = 0;
    if (old_player_state[id] > State_InJump_FirstFrame && player_state[id] == State_Initial && get_player_hspeed(id) > 450.0)
        inertia_frames[id]++;
    else if (inertia_frames[id] > 0 && old_player_state[id] == State_Initial
            && (player_state[id] == State_Initial || player_state[id] == State_InJump_FirstFrame))
        inertia_frames[id]++;
    else
        inertia_frames[id] = 0;

    old_player_state[id] = player_state[id];

    new Float:someMeasurement = floatsqroot(
        ( origin[id][0] - oldorigin[id][0] ) * ( origin[id][0] - oldorigin[id][0] ) +
        ( origin[id][1] - oldorigin[id][1] ) * ( origin[id][1] - oldorigin[id][1] ) );
    if( air_touch[id] )
    {
        air_touch[id] = false;
        
        if( !( flags[id] & FL_ONGROUND2 ) && !( oldflags[id] & FL_ONGROUND2 ) )
        {
            event_jump_illegal( id );
        }
    }
    // else if( gravity != 1.0 
    // || ( pev( id, pev_waterlevel ) != 0 )
    else if( 
       ( pev( id, pev_waterlevel ) != 0 )
    || ( ( movetype[id] != MOVETYPE_WALK ) && ( movetype[id] != MOVETYPE_FLY ) )
    || ( someMeasurement > 20.0 )
    // || ( get_pcvar_num( sv_gravity ) != 800 )
    // || ( get_pcvar_num( sv_airaccelerate ) != 10 )
    )
    {
        event_jump_illegal( id );
    }
    else
    {
        // run current state func / no function pointers in pawn :(
        switch ( player_state[id] )
        {
            case State_Initial:
            {
                state_initial( id );
            }
            case State_InJump_FirstFrame:
            {
                state_injump_firstframe( id );
            }
            case State_InJump:
            {
                state_injump( id );
            }
            case State_InDD_FirstFrame:
            {
                state_indd_firstframe( id );
            }
            case State_InDD:
            {
                state_indd( id );
            }
            case State_InDrop:
            {
                state_indrop( id );
            }
            case State_InFall:
            {
                state_infall( id );
            }
            case State_OnLadder:
            {
                state_onladder( id );
            }
            case State_InLadderDrop:
            {
                state_inladderdrop( id );
            }
            default:
            {
                // this shouldn't happen
                reset_state( id );
            }
        }
    }
    
    oldflags[id] = flags[id];
    oldbuttons[id] = buttons[id];
    oldorigin[id] = origin[id];
    oldvelocity[id] = velocity[id];
}

state_initial( id )
{
    if( movetype[id] == MOVETYPE_WALK )
    {
        if( flags[id] & FL_ONGROUND2 )
        {
            if( ( buttons[id] & IN_JUMP ) )
            {
                event_jump_begin( id );
                player_state[id] = State_InJump_FirstFrame;
            }
            else if( !( buttons[id] & IN_DUCK ) && ( oldbuttons[id] & IN_DUCK ) )
            {
                event_dd_begin( id );
                player_state[id] = State_InDD_FirstFrame;
            }
        }
        else
        {
            player_state[id] = State_InFall;
            state_infall( id );
        }
    }
    else // if it's not movetype_walk, it must be movetype_fly (see the prethink function)
    {
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

event_jump_begin( id )
{
    jump_start_ducking[id] = ducking[id];
    jump_start_origin[id] = origin[id];
    jump_start_velocity[id] = velocity[id];
    jump_start_time[id] = get_gametime( );
    jump_prestrafe[id] = floatsqroot( jump_start_velocity[id][0] * jump_start_velocity[id][0] + jump_start_velocity[id][1] * jump_start_velocity[id][1] );
    jump_maxspeed[id] = jump_prestrafe[id];
    jump_speed[id] = jump_prestrafe[id];
    pev( id, pev_angles, jump_angles[id] );
    
}

state_injump_firstframe( id )
{
    // client_print(id, print_chat, "jump: %s", jump_name[jump_type[id]]);
    if( movetype[id] == MOVETYPE_WALK )
    {
        // multi bhop не добавлен в этот switch, значит он всегда включен 
        // TODO: tidy up this code -- begin
        new bool:bJumpTypeDisabled = false;
        jump_type[id] = get_jump_type( id );

        // временно закоментил, позже если плагин будет дорабатываться нужно это раскоментить
        // причина закоментаривания в том, что 1ый прыжок считается longjump'ом и не выводится на экран потому что игрок не включил
        // соответствующий пункт в своём меню /stats

        // switch (jump_type[id])
        // {
        //     case JumpType_LJ: if (!g_DisplayLJStats[id]) bJumpTypeDisabled = true;
        //     case JumpType_HJ: if (!g_DisplayHJStats[id]) bJumpTypeDisabled = true;
        //     case JumpType_CJ, JumpType_DCJ, JumpType_MCJ, JumpType_DropCJ: if (!g_DisplayCJStats[id]) bJumpTypeDisabled = true;
        //     case JumpType_WJ: if (!g_DisplayWJStats[id]) bJumpTypeDisabled = true;
        //     case JumpType_BJ, JumpType_SBJ, JumpType_DropBJ: if (!g_DisplayBhStats[id]) bJumpTypeDisabled = true;
        //     case JumpType_LadderBJ: if (!g_DisplayLadderStats[id]) bJumpTypeDisabled = true;
        //     default: bJumpTypeDisabled = false;
        // }

        if(!g_DisplaySimpleStats[id])
        {
            bJumpTypeDisabled = true;
        }


        if (inertia_frames[id] && (get_player_hspeed(id) > 400.0 || velocity[id][2] > 400.0)
                && (jump_type[id] == JumpType_LJ || jump_type[id] == JumpType_HJ))
            bJumpTypeDisabled = true;
        else
            inertia_frames[id] = 0;
        // TODO: tidy up this code -- end


        if( (flags[id] & FL_ONGROUND2) || bJumpTypeDisabled )
        {
            
            player_state[id] = State_Initial;
            state_initial( id );
            
            return;
        }
        
        jump_first_origin[id] = origin[id];
        jump_first_velocity[id] = velocity[id];
        
        set_hudmessage( 255, 128, 0, -1.0, 0.7, 0, 0.0, 1.0, 0.0, 0.1, 1 );
        for( new i = 1, players = get_maxplayers( ); i <= players; ++i )
        {
            if( ( ( i == id ) || ( pev( i, pev_iuser2 ) == id ) ) && player_show_prestrafe[i] )
            {
                show_hudmessage( i, "%s: %.2f", jump_shortname[jump_type[id]], jump_prestrafe[id] );
            }
        }
        
        player_state[id] = State_InJump;
        state_injump( id );
    }
    else
    {
        
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

state_injump( id )
{
    if( movetype[id] == MOVETYPE_WALK )
    {
        static Float:h1;
        static Float:h2;
        static Float:correct_old_h2;
        h1 = ( jump_start_ducking[id] ? jump_start_origin[id][2] + 18.0 : jump_start_origin[id][2] );
        h2 = ( ducking[id] ? origin[id][2] + 18.0 : origin[id][2] );

        if (oldDucking[id] < ducking[id])
            correct_old_h2 = old_h2_injump[id] + 18.0;
        else if (oldDucking[id] > ducking[id])
            correct_old_h2 = old_h2_injump[id] - 18.0;
        else
            correct_old_h2 = old_h2_injump[id];

        if( ( ( origin[id][2] + 18.0 ) < jump_start_origin[id][2] )
            || ( ( flags[id] & FL_ONGROUND2 ) && ( h2 < jump_start_origin[id][2] ) )
            || obbo[id])
        {
            event_jump_failed( id );
            
            player_state[id] = State_InDrop;
            state_indrop( id );

            old_h2_injump[id] = h2;

            obbo[id] = false;
            return;
        }

        if ( ( correct_old_h2 < h2 ) && old_player_state[id] == player_state[id] && injump_started_downward[id] )
        {
            // this check is because the plugin doesn't realize when the player started another jump when doing perfect autojumping,
            // like FL_ONGROUND is not set when touching the ground for start the next jump
            reset_state( id );
        }

        injump_frame[id]++;
        // when jumping in hl1 it may do something weird as having the second frame of the
        // jump in a lower Z origin than the first frame, which shouldn't happen becase
        // if you jump you should gain Z until you reach the top of the jump, but sometimes
        // it's just not the case somehow
        if (correct_old_h2 > h2 && injump_frame[id] > 2)
            injump_started_downward[id] = true;

        old_h2_injump[id] = h2;
        

        if( flags[id] & FL_ONGROUND2)
        {

            event_jump_end( id );
            
            injump_started_downward[id] = false;
            injump_frame[id] = 0;
            player_state[id] = State_Initial;
            state_initial( id );
            
            return;
        }
        
        if( h2 >= h1 )
        {
            jump_fail_origin[id] = origin[id];
            jump_fail_velocity[id] = velocity[id];
        }
        
        jump_last_origin[id] = origin[id];
        jump_last_velocity[id] = velocity[id];
        
        static Float:speed;
        speed = floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] );
        if( jump_maxspeed[id] < speed )
            jump_maxspeed[id] = speed;
        
        if( speed > jump_speed[id] )
        {
            ++jump_sync[id];
            
            if( jump_strafes[id] < MAX_STRAFES )
            {
                ++jump_strafe_sync[id][jump_strafes[id]];
                jump_strafe_gain[id][jump_strafes[id]] += speed - jump_speed[id];
            }
        }
        else
        {
            if( jump_strafes[id] < MAX_STRAFES )
            {
                jump_strafe_loss[id][jump_strafes[id]] += jump_speed[id] - speed;
            }
        }
        
        static Float:angles[3];
        pev( id, pev_angles, angles );
        if( jump_angles[id][1] > angles[1] )
        {
            jump_turning[id] = 1;
        }
        else if( jump_angles[id][1] < angles[1] )
        {
            jump_turning[id] = -1;
        }
        else
        {
            jump_turning[id] = 0;
        }
        
        if( jump_turning[id] )
        {
            if( ( jump_strafing[id] != -1 ) && ( buttons[id] & ( IN_MOVELEFT | IN_FORWARD ) ) && !( buttons[id] & ( IN_MOVERIGHT | IN_BACK ) ) )
            {
                jump_strafing[id] = -1;
                ++jump_strafes[id];
            }
            else if( ( jump_strafing[id] != 1 ) && ( buttons[id] & ( IN_MOVERIGHT | IN_BACK ) ) && !( buttons[id] & ( IN_MOVELEFT | IN_FORWARD ) ) )
            {
                jump_strafing[id] = 1;
                ++jump_strafes[id];
            }
        }
        
        ++jump_frames[id];
        if( jump_strafes[id] < MAX_STRAFES )
        {
            ++jump_strafe_frames[id][jump_strafes[id]];
        }
        
        jump_speed[id] = speed;
        jump_angles[id] = angles;
    }
    else
    {
        
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

event_jump_failed( id )
{
    static Float:jumpoff_height;
    jumpoff_height = jump_start_origin[id][2];
    if( flags[id] & FL_DUCKING )
    {
        jumpoff_height -= 18.0;
    }
    
    new Float:airtime = ( -oldvelocity[id][2] - floatsqroot( oldvelocity[id][2] * oldvelocity[id][2] - 2.0 * -800 * ( oldorigin[id][2] - jumpoff_height ) ) ) / -800;
    
    static Float:distance_x;
    static Float:distance_y;
    distance_x = floatabs( oldorigin[id][0] - jump_start_origin[id][0] ) + floatabs( velocity[id][0] * airtime );
    distance_y = floatabs( oldorigin[id][1] - jump_start_origin[id][1] ) + floatabs( velocity[id][1] * airtime );
    
    jump_distance[id] = floatsqroot( distance_x * distance_x + distance_y * distance_y ) + 32.0;
    
    if (jump_frames[id])
        display_stats( id );
    
    
    reset_stats( id );
}

event_jump_end( id )
{
    jump_end_ducking[id] = ducking[id];
    jump_end_origin[id] = origin[id];
    jump_end_time[id] = get_gametime( );
    
    new Float:h1 = ( jump_start_ducking[id] ? jump_start_origin[id][2] + 18.0 : jump_start_origin[id][2] );
    new Float:h2 = ( jump_end_ducking[id] ? jump_end_origin[id][2] + 18.0 : jump_end_origin[id][2] );
    
    if( h1 == h2 )
    {
        static Float:dist1;
        static Float:dist2;
        
        dist1 = floatsqroot(
            ( jump_start_origin[id][0] - jump_end_origin[id][0] ) * ( jump_start_origin[id][0] - jump_end_origin[id][0] ) +
            ( jump_start_origin[id][1] - jump_end_origin[id][1] ) * ( jump_start_origin[id][1] - jump_end_origin[id][1] ) );
        
        static Float:airtime;
        airtime = ( -floatsqroot( jump_first_velocity[id][2] * jump_first_velocity[id][2] + ( 1600.0 * ( jump_first_origin[id][2] - origin[id][2] ) ) ) - oldvelocity[id][2] ) / -800.0;
        
        static Float:cl_origin[2];
        if( oldorigin[id][0] < origin[id][0] )	cl_origin[0] = oldorigin[id][0] + airtime * floatabs( oldvelocity[id][0] );
        else									cl_origin[0] = oldorigin[id][0] - airtime * floatabs( oldvelocity[id][0] );
        if( oldorigin[id][1] < origin[id][1] )	cl_origin[1] = oldorigin[id][1] + airtime * floatabs( oldvelocity[id][1] );
        else									cl_origin[1] = oldorigin[id][1] - airtime * floatabs( oldvelocity[id][1] );
        
        dist2 = floatsqroot(
            ( jump_start_origin[id][0] - cl_origin[0] ) * ( jump_start_origin[id][0] - cl_origin[0] ) +
            ( jump_start_origin[id][1] - cl_origin[1] ) * ( jump_start_origin[id][1] - cl_origin[1] ) );
        
        jump_distance[id] = floatmin( dist1, dist2 ) + 32.0;
        
        display_stats( id );
    }
    
    reset_stats( id );
}

event_jump_illegal( id )
{
    // client_print(id, print_chat, "jump illegal: %s", jump_name[jump_type[id]]);
    reset_state( id );
}

event_dd_begin( id )
{
    if( ( dd_start_origin[id][2] == dd_end_origin[id][2] ) && ( dd_end_origin[id][2] == origin[id][2] ) && ( get_gametime( ) - dd_end_time[id] < 0.1 ) )
    {
        ++dd_count[id];
    }
    else
    {
        dd_count[id] = 1;
    }
    
    dd_start_origin[id] = origin[id];
    dd_start_time[id] = get_gametime( );
    
    if( dd_count[id] > 3 )
    {
        dd_prestrafe[id][0] = dd_prestrafe[id][1];
        dd_prestrafe[id][1] = dd_prestrafe[id][2];
        dd_prestrafe[id][2] = floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] );
    }
    else
    {
        dd_prestrafe[id][dd_count[id] - 1] = floatsqroot( velocity[id][0] * velocity[id][0] + velocity[id][1] * velocity[id][1] );
    }
    
}

state_indd_firstframe( id )
{
    if( movetype[id] == MOVETYPE_WALK )
    {
        if( flags[id] & FL_ONGROUND2 )
        {
            
            player_state[id] = State_Initial;
            state_initial( id );
            
            return;
        }
        
        player_state[id] = State_InDD;
        state_indd( id );
    }
    else
    {
        
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

state_indd( id )
{
    if( movetype[id] == MOVETYPE_WALK )
    {
        if( flags[id] & FL_ONGROUND2 )
        {
            event_dd_end( id );
            
            player_state[id] = State_Initial;
            state_initial( id );
            
            return;
        }
        
        if( ( origin[id][2] + 18.0 ) < dd_start_origin[id][2] )
        {
            
            player_state[id] = State_InFall;
            state_infall( id );
        }
    }
    else
    {
        
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

event_dd_end( id )
{
    
    dd_end_origin[id] = origin[id];
    dd_end_time[id] = get_gametime( );
}

state_indrop( id )
{
    if( movetype[id] == MOVETYPE_WALK )
    {
        if( flags[id] & FL_ONGROUND2 )
        {
            drop_origin[id] = origin[id];
            drop_time[id] = get_gametime( );
            
            player_state[id] = State_Initial;
            state_initial( id );
            
            return;
        }
    }
    else
    {
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

state_infall( id )
{
    if( movetype[id] == MOVETYPE_WALK )
    {
        if( flags[id] & FL_ONGROUND2 )
        {
            // server_print("state infall: %f",  fall_time[id] );
            // client_print(id, print_chat, "state: %d %d", player_state[id], State_InFall);

            fall_origin[id] = origin[id];
            fall_time[id] = get_gametime( );
            
            player_state[id] = State_Initial;
            state_initial( id );
            
            return;
        }
    }
    else
    {
        player_state[id] = State_OnLadder;
        state_onladder( id );
    }
}

state_onladder( id )
{
    if( movetype[id] == MOVETYPE_FLY )
    {
        if( ( buttons[id] & IN_JUMP ) && !( oldbuttons[id] & IN_JUMP ) )
        {
            player_state[id] = State_InLadderDrop;
        }
    }
    else if( movetype[id] == MOVETYPE_WALK )
    {
        player_state[id] = State_Initial;
        state_initial( id );
    }
}

state_inladderdrop( id )
{
    if( flags[id] & FL_ONGROUND2 )
    {
        ladderdrop_origin[id] = origin[id];
        ladderdrop_time[id] = get_gametime( );
        
        player_state[id] = State_Initial;
        state_initial( id );
    }
}

JumpType:get_jump_type( id )
{
    if( jump_start_time[id] - ladderdrop_time[id] < 0.1 ) // z-origin check?
    {
        return JumpType_LadderBJ;
    }
    else if( jump_start_time[id] - dd_end_time[id] < 0.1 ) // z-origin check?
    {
        if( ( dd_start_time[id] - drop_time[id] < 0.1 ) || ( dd_start_time[id] - fall_time[id] < 0.1 ) )
        {
            return JumpType_DropCJ;
        }
        else
        {
            if( dd_count[id] == 1 )
                return JumpType_CJ;
            else if( dd_count[id] == 2 )
                return JumpType_DCJ;
            else
                return JumpType_MCJ;
        }
    }
    else if( jump_start_time[id] - fall_time[id] < 0.1 ) // z-origin check?
    {

        if(!(flags[id] & FL_ONGROUND2))
        {
            // server_print("MBJ: %f %f %b",  jump_start_time[id] , fall_time[id] , flags[id] & FL_ONGROUND2);
            return JumpType_MultiBJ;
        }
        // server_print("WJ: %f %f %b",  jump_start_time[id] , fall_time[id] , flags[id] & FL_ONGROUND2);
        return JumpType_WJ;
    }
    else if( jump_start_time[id] - drop_time[id] < 0.1 ) // z-origin check?
    {
        return JumpType_DropBJ;
    }
    else if( jump_start_time[id] - jump_end_time[id] < 0.1 ) // z-origin check?
    {
        if(!(flags[id] & FL_ONGROUND2))
        {
            // server_print("MBJ: %f %f %b",  jump_start_time[id] , fall_time[id] , flags[id] & FL_ONGROUND2);
            return JumpType_MultiBJ;
        }

        if( velocity[id][2] > 230.0 )
            return JumpType_SBJ;
        else
            return JumpType_BJ;
    }
    else
    {
        static Float:length;
        static Float:start[3], Float:stop[3], Float:maxs_Z;
        
        maxs_Z = flags[id] & FL_DUCKING ? 18.0 : 36.0;
        length = vector_length( jump_start_velocity[id] );
        
        start[0] = jump_start_origin[id][0] + ( jump_start_velocity[id][0] / length * 8.0 );
        start[1] = jump_start_origin[id][1] + ( jump_start_velocity[id][1] / length * 8.0 );
        start[2] = jump_start_origin[id][2] - maxs_Z;
        
        stop[0] = start[0];
        stop[1] = start[1];
        stop[2] = start[2] - 70.0;
        
        engfunc( EngFunc_TraceLine, start, stop, 0, id );
        
        static Float:fraction;
        global_get( glb_trace_fraction, fraction );

        
        if( !( fraction < 1.0 ) )
            return JumpType_HJ;
        else
            return JumpType_LJ;
    }
}

display_stats( id, bool:failed = false )
{
    static jump_info[256];
    formatex( jump_info, charsmax(jump_info), "Strafes: %d, Sync: %d, Gain: %f",
            jump_strafes[id],
            jump_sync[id] * 100 / jump_frames[id],
            jump_maxspeed[id] - jump_prestrafe[id]
    );
    // formatex( jump_info, charsmax(jump_info), "%s: %.2f^nMaxspeed: %.2f (%.2f)^nPrestrafe: %.2f^nStrafes: %d^nSync: %d",
    //         jump_name[jump_type[id]],
    //         jump_distance[id],
    //         jump_maxspeed[id],
    //         jump_maxspeed[id] - jump_prestrafe[id],
    //         jump_prestrafe[id],
    //         jump_strafes[id],
    //         jump_sync[id] * 100 / jump_frames[id]
    // );
    
    static jump_info_console[128];
    formatex( jump_info_console, charsmax(jump_info_console), "%s Distance: %f Maxspeed: %f (%.2f) Prestrafe: %f Strafes %d Sync: %d",
        jump_shortname[jump_type[id]],
        jump_distance[id],
        jump_maxspeed[id],
        jump_maxspeed[id] - jump_prestrafe[id],
        jump_prestrafe[id],
        jump_strafes[id],
        jump_sync[id] * 100 / jump_frames[id]
    );
    
    /*
    static strafes_info[512];
    static strafes_info_console[MAX_STRAFES][40];
    if( jump_strafes[id] > 1 )
    {
        new len;
        for( new i = 1; i < sizeof(jump_strafes[]); ++i )
        {
            formatex( strafes_info_console[i], charsmax(strafes_info_console[]), "^t%d^t%.3f^t%.3f^t%d^t%d",
                i,
                jump_strafe_gain[id][i],
                jump_strafe_loss[id][i],
                jump_strafe_frames[id][i] * 100 / jump_frames[id],
                jump_strafe_sync[id][i] * 100 / jump_strafe_frames[id][i]
            );
            len += formatex( strafes_info[len], charsmax(strafes_info) - len, "%s^n", strafes_info_console[i] );
        }
    }
    */
    
    for( new i = 1, players = get_maxplayers( ); i <= players; ++i )
    {
        if( player_show_stats[i] && ( ( i == id ) || ( ( ( pev( i, pev_iuser1 ) == 2 ) || ( pev( i, pev_iuser1 ) == 4 ) ) && ( pev( i, pev_iuser2 ) == id ) ) ) )
        {
            if( failed )
                set_hudmessage( 255, 0, 0, -1.0, 0.7, 0, 0.0, 3.0, 0.0, 0.1, 1 );
            else
                set_hudmessage( 255, 128, 0, -1.0, 0.7, 0, 0.0, 3.0, 0.0, 0.1, 1 );
            show_hudmessage( i, "%s", jump_info );
            
            /*
            if( failed )
                set_hudmessage( 255, 0, 0, 0.7, -1.0, 0, 0.0, 3.0, 0.0, 0.1, 2 );
            else
                set_hudmessage( 255, 128, 0, 0.7, -1.0, 0, 0.0, 3.0, 0.0, 0.1, 2 );
            show_hudmessage( i, "%s", strafes_info );
            */

            console_print( i, "%s", jump_info_console );
            //for( new j = 1; j <= jump_strafes[id]; ++j )
            //	console_print( i, "%s", strafes_info_console[j] );
        }
        
        // static jump_info_chat[192];
        // jump_info_chat[0] = 0;
        // if( !failed )
        // {
        //     if( player_show_stats[i] && player_show_stats_chat[i] && ( !g_MuteJumpMessages[i] || id == i ) )
        //     {
        //         new name[32];
        //         get_user_name( id, name, charsmax(name) );

        //         if( jump_distance[id] >= jump_level[jump_type[id]][4] )
        //         {
        //             formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_GODLIKE", name, jump_shortname[jump_type[id]], jump_distance[id] );
        //         }
        //         else if( jump_distance[id] >= jump_level[jump_type[id]][3] )
        //         {
        //             formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_PERFECT", name, jump_shortname[jump_type[id]], jump_distance[id] );
        //         }
        //         else if( jump_distance[id] >= jump_level[jump_type[id]][2] )
        //         {
        //             formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_IMPRESSIVE", name, jump_shortname[jump_type[id]], jump_distance[id] );
        //         }
        //         else if( jump_distance[id] >= jump_level[jump_type[id]][1] )
        //         {
        //             formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_LEET", name, jump_shortname[jump_type[id]], jump_distance[id] );
        //         }
        //         else if( jump_distance[id] >= jump_level[jump_type[id]][0] )
        //         {
        //             formatex( jump_info_chat, charsmax(jump_info_chat), "%L", i, "Q_JS_PRO", name, jump_shortname[jump_type[id]], jump_distance[id] );
        //         }
                
        //         if( jump_info_chat[0] )
        //         {
        //             new pre[7], dist[7], maxs[7], gain[6], sync[4], strafes[3];
        //             float_to_str( jump_prestrafe[id], pre, charsmax(pre) ); // prestrafe speed
        //             float_to_str( jump_distance[id], dist, charsmax(dist) ); // distance from jump start to end point
        //             float_to_str( jump_maxspeed[id], maxs, charsmax(maxs) ); // maxspeed during jump
        //             float_to_str( jump_maxspeed[id] - jump_prestrafe[id], gain, charsmax(gain) ); // gain
        //             num_to_str( jump_sync[id], sync, charsmax(sync) ); // sync
        //             num_to_str( jump_strafes[id], strafes, charsmax(strafes) ); // strafes during jump
                    
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!name", name );
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!dist", dist );
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!pre", pre );
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!maxs", maxs );
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!gain", gain );
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!sync", sync );
        //             replace_all( jump_info_chat, charsmax(jump_info_chat), "!strf", strafes );
                    
        //             q_message_SayText( i, MSG_ONE, _, i, "%s", jump_info_chat );
        //         }
        //     }
        // }
    }
}


Float:get_player_hspeed(id)
{
    new Float:velocity[3];
    pev(id, pev_velocity, velocity);
    return floatsqroot(floatpower(velocity[0], 2.0) + floatpower(velocity[1], 2.0));
}


