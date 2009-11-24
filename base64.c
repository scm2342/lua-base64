#include <lua.h>
#include <lauxlib.h>
#include <string.h>

static int l_b64e(lua_State *L)
{
	const char *s3 = luaL_checkstring(L, 1);
	const char *base64_alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	char c[5];

	if(s3 == NULL || strlen(s3) != 3)
	{
		lua_pushnil(L);
		lua_pushstring(L, "you have to supply a 3 byte string");
		return 2;
	}

	c[0] = base64_alpha[(s3[0] & 0xfc) >> 2];
	c[1] = base64_alpha[((s3[0] & 0x03) << 4) + ((s3[1] & 0xf0) >> 4)];
	c[2] = base64_alpha[((s3[1] & 0x0f) << 2) + ((s3[2] & 0xc0) >> 6)];
	c[3] = base64_alpha[s3[2] & 0x3f];
	c[4] = '\0';

	lua_pushstring(L, c);
	return 1;
}

static const struct luaL_Reg base64[] = {
	{"e", l_b64e},
	{NULL, NULL}
};

int luaopen_base64(lua_State *L)
{
	luaL_register(L, "base64", base64);
	return 1;
}
