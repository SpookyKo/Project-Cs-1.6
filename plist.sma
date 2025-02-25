#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#define PLUGIN "Player Logger"
#define VERSION "1.1"
#define AUTHOR "CHATGPT + SPOOKY1337"

new Handle:sqlConnection;

// Configurare MySQL direct in plugin
#define MYSQL_HOST "IP-DB"
#define MYSQL_USER "USER-DB"
#define MYSQL_PASS "PASSWORD-DB"
#define MYSQL_DB "DB-NAME"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_clcmd("say /plist", "cmd_showPlayerList", ADMIN_RCON);
    
    SQL_Init();
    set_task(86400.0, "CleanOldLogs", _, _, _, "b");
}

public SQL_Init() {
    sqlConnection = SQL_MakeDbTuple(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB);
    
    if (sqlConnection == Empty_Handle) {
        server_print("[AMXX] Eroare: Nu s-a putut inițializa conexiunea MySQL!");
        return;
    }
    
    new szQuery[1024];
    format(szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS player_log (id INT AUTO_INCREMENT PRIMARY KEY, steamid VARCHAR(32), playername VARCHAR(64), date DATE, UNIQUE(steamid, date));");
    SQL_ThreadQuery(sqlConnection, "QueryCallback", szQuery);
}

public QueryCallback(failstate, Handle:query, error[], errnum, data) {
    if (failstate == TQUERY_CONNECT_FAILED) {
        server_print("[AMXX] Eroare la conectarea la MySQL: %s", error);
    } else if (failstate == TQUERY_QUERY_FAILED) {
        server_print("[AMXX] Eroare la rularea query-ului: %s", error);
    }
}

public client_putinserver(id) {
    if (sqlConnection == Empty_Handle) return;
    
    new szAuthID[32], szName[64], szDate[12], szQuery[256];
    get_user_authid(id, szAuthID, charsmax(szAuthID));
    get_user_name(id, szName, charsmax(szName));
    get_time("%Y-%m-%d", szDate, charsmax(szDate));
    
    format(szQuery, charsmax(szQuery), "INSERT IGNORE INTO player_log (steamid, playername, date) VALUES ('%s', '%s', '%s');", szAuthID, szName, szDate);
    SQL_ThreadQuery(sqlConnection, "QueryCallback", szQuery);
}

public cmd_showPlayerList(id) {
    if (!(get_user_flags(id) & ADMIN_RCON)) {
        client_print(id, print_chat, "[Logger Player] Nu ai permisiunea de a folosi aceasta comanda.");
        return;
    }
    if (sqlConnection == Empty_Handle) {
        client_print(id, print_chat, "[AMXX] Conexiune MySQL indisponibilă.");
        return;
    }
    SQL_ThreadQuery(sqlConnection, "ShowPlayersCallback", "SELECT COUNT(DISTINCT steamid) FROM player_log WHERE date >= DATE_SUB(CURDATE(), INTERVAL 1 DAY);");
}

public ShowPlayersCallback(failstate, Handle:query, error[], errnum, data) {
    if (failstate != TQUERY_SUCCESS) {
        server_print("[AMXX] Eroare la interogarea MySQL: %s", error);
        return;
    }
    
    new count = 0; // Inițializare explicită
    if (SQL_NumResults(query) > 0) {
        count = SQL_ReadResult(query, 0);
    }
    
    new szMessage[128];
    format(szMessage, charsmax(szMessage), "[Logger Player] Numar jucatori in ultimele 24h: %d", count);
    client_print(0, print_chat, "%s", szMessage);
} 

public CleanOldLogs() {
    if (sqlConnection == Empty_Handle) return;

    new szQuery[128];
    format(szQuery, charsmax(szQuery), "DELETE FROM player_log WHERE date < DATE_SUB(CURDATE(), INTERVAL 1 DAY);");
    SQL_ThreadQuery(sqlConnection, "QueryCallback", szQuery);
}
