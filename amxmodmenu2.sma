#include <amxmodx>

#define SECONDS_IN_DAY 86400
#define MAX_MENU_ITEMS 64

enum _:MenuData {
  ItemName[64],
  ItemCmd[32],
  ItemFlag
}

enum _:MenuSettings {
  MenuName[64],
  MenuCmd[32],
  MenuPage[4],
  MenuFlag
}

new Array:g_eMenuData;
new g_eMenuSettings[MenuSettings];
new g_iMenusNum;
new g_iMenuPos[MAX_PLAYERS + 1];

public plugin_precache() {
  new szPath[128];
  get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
  add(szPath, charsmax(szPath), "/amxmodmenu/amxmodmenu.ini");
  
  new hFile = fopen(szPath, "rt");
  if (!hFile) {
      set_fail_state("Can't %s '%s'", file_exists(szPath) ? "read" : "find", szPath);
      return;
  }

  g_eMenuData = ArrayCreate(MenuData);

  new szLine[128], szType[24], szName[64], szCmd[32], szFlag[4], szMenuData[MenuData];

  while (fgets(hFile, szLine, charsmax(szLine))) {
      trim(szLine);
      if (szLine[0] == ';' || !szLine[0]) continue;

      if (parse(szLine, szType, charsmax(szType), szCmd, charsmax(szCmd)) == 2) {
          if (equali(szType, "display_menu_page")) {
              copy(g_eMenuSettings[MenuPage], charsmax(g_eMenuSettings[MenuPage]), szCmd);
              continue;
          }
      }

      if (parse(szLine, szType, charsmax(szType), szName, charsmax(szName), szCmd, charsmax(szCmd), szFlag, charsmax(szFlag)) == 4) {
          replace_all(szName, charsmax(szName), "^^n", "^n");
          replace_all(szName, charsmax(szName), "^^t", "^t");

          if (equali(szType, "reg_main_menu")) {
              copy(g_eMenuSettings[MenuName], charsmax(g_eMenuSettings[MenuName]), szName);
              copy(g_eMenuSettings[MenuCmd], charsmax(g_eMenuSettings[MenuCmd]), szCmd);
              g_eMenuSettings[MenuFlag] = read_flags(szFlag);
          } else if (equali(szType, "add_menu_item")) {
              copy(szMenuData[ItemName], charsmax(szMenuData[ItemName]), szName);
              copy(szMenuData[ItemCmd], charsmax(szMenuData[ItemCmd]), szCmd);
              szMenuData[ItemFlag] = read_flags(szFlag);
              ArrayPushArray(g_eMenuData, szMenuData);
          }
      }
  }

  fclose(hFile);
  g_iMenusNum = ArraySize(g_eMenuData);
}

public plugin_init() {
  register_plugin("[Customizable] AmxModMenu", "0.0.6", "Albertio");
  register_concmd(g_eMenuSettings[MenuCmd], "AmxModMenu_Cmd", g_eMenuSettings[MenuFlag]);
  register_clcmd("nightvision", "Handle_NightvisionKey");
  register_menucmd(register_menuid("AmxModMenu"), 1023, "AmxModMenu_Handler");
}

public Handle_NightvisionKey(id) {
  if (get_user_flags(id) & g_eMenuSettings[MenuFlag]) {
      AmxModMenu_Cmd(id, g_eMenuSettings[MenuFlag]);
      return PLUGIN_HANDLED;
  }
  return PLUGIN_CONTINUE;
}

public AmxModMenu_Cmd(id, iFlag) {
  if (~get_user_flags(id) & iFlag) {
      console_print(id, "You don't have enough rights to use this command");
      return PLUGIN_HANDLED;
  }
  
  AmxModMenu_Display(id, g_iMenuPos[id] = 0);
  return PLUGIN_HANDLED;
}

public AmxModMenu_Display(id, iPos) {
  if (iPos < 0) return PLUGIN_HANDLED;

  new szMenu[512], iLen, iKeys = MENU_KEY_0;
  new iStart = iPos * 8, iEnd = min(iStart + 8, g_iMenusNum), iNum;
  new szMenuData[MenuData];

  if (iStart >= g_iMenusNum) {
      iStart = iPos = g_iMenuPos[id] = 0;
  }

  iLen = formatex(szMenu, charsmax(szMenu), "\y%s\R%s%d/%d^n^n", 
      g_eMenuSettings[MenuName],
      g_eMenuSettings[MenuPage][0] == '1' ? "\y" : "",
      g_eMenuSettings[MenuPage][0] == '1' ? iPos + 1 : 0,
      g_eMenuSettings[MenuPage][0] == '1' ? (g_iMenusNum / 8 + ((g_iMenusNum % 8) > 0 ? 1 : 0)) : 0
  );

  new iFlags = get_user_flags(id);
  for (new i = iStart; i < iEnd; i++) {
      ArrayGetArray(g_eMenuData, i, szMenuData);
      if (iFlags & szMenuData[ItemFlag]) {
          iKeys |= (1 << iNum);
          iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w %s^n", ++iNum, szMenuData[ItemName]);
      } else {
          iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d%d. %s^n", ++iNum, szMenuData[ItemName]);
      }
  }

  if (iEnd != g_iMenusNum) {
      iKeys |= MENU_KEY_9;
      iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9.\w Next^n\r0.\w %s", iPos ? "Back" : "Exit");
  } else {
      iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0.\w %s", iPos ? "Back" : "Exit");
  }

  show_menu(id, iKeys, szMenu, -1, "AmxModMenu");
  return PLUGIN_HANDLED;
}

public AmxModMenu_Handler(id, key) {
  switch (key) {
      case 8: AmxModMenu_Display(id, ++g_iMenuPos[id]);
      case 9: AmxModMenu_Display(id, --g_iMenuPos[id]);
      default: {
          new szMenuData[MenuData];
          ArrayGetArray(g_eMenuData, g_iMenuPos[id] * 8 + key, szMenuData);
          
          if (szMenuData[ItemCmd][0] == 's' && szMenuData[ItemCmd][1] == 'v' && szMenuData[ItemCmd][2] == '_') {
              server_cmd(szMenuData[ItemCmd]);
          } else {
              client_cmd(id, szMenuData[ItemCmd]);
          }
      }
  }
  return PLUGIN_HANDLED;
}