local skynet = require 'skynet'

return {
	post = function(self)
		ngx.req.read_body()
		local post = ngx.req.get_post_args()
		local cjson = require 'cjson'
		local inst = post.inst
		local app = post.app
		local version = post.version
		assert(inst and app)
		local id = "from_web"
		local args = {
			version = version,
			inst = inst,
			name = app,
		}
		skynet.call("UPGRADER", "lua", "upgrade_app", id, args)
		ngx.print('Application upgrade is done!')
	end,
}
