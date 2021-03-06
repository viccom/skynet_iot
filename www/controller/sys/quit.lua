local skynet = require 'skynet'

return {
	post = function(self)
		ngx.req.read_body()
		local post = ngx.req.get_post_args()
		local id = "from_web"
		local args = {
			from_web = true,
			delay = 5,
		}
		skynet.call("UPGRADER", "lua", "system_quit", id, args)
		ngx.print('System will be quit after five seconds!')
	end,
}
