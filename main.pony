use "cli"
use "http"
use "files"
use "net_ssl"

primitive BaseUrl fun apply(): String => "https://api.twitch.tv/kraken"

actor Main
    new create(env: Env) =>
        let command = try
            CommandSpec.leaf("streamers", "", [], [
                ArgSpec.string_seq("users", "Username")
            ])?.>add_help()?
        else
            env.exitcode(1)
            return
        end

        let parsed =
            match CommandParser(command).parse(env.args, env.vars)
            | let cmd: Command => cmd
            | let ch: CommandHelp =>
                ch.print_help(env.out)
                env.exitcode(0)
                return
            | let err: SyntaxError =>
                env.out.print(err.string())
                env.exitcode(1)
                return
            end

        let users = parsed.arg("users").string_seq()
        let url = try
            let builder = UrlBuilder(BaseUrl)
            for user in users.values() do
                builder.login(user)
            end
            builder.build()?
        else
            env.exitcode(1)
            return
        end

        let clientId = try
            EnvVars(env.vars)("TWITCH_CLIENT_ID")?
        else
            env.exitcode(1)
            return
        end
        _Get(env, url, clientId)

class UrlBuilder
    let _baseUrl: String
    var _url: String

    new create(baseUrl: BaseUrl) =>
        _baseUrl = baseUrl() + "/users"
        _url = _baseUrl

    fun ref login(login': String): UrlBuilder =>
        if _baseUrl == _url then
            _url = _url + "?login=" + login'
        else
            _url = _url + "," + login'
        end
        this

    fun build(): URL ? => URL.valid(_url)?

actor _Get
    let _env: Env

    new create(env: Env, url: URL, clientId: String) =>
        _env = env
        let sslctl = try
            recover
                SSLContext
                    .>set_client_verify(true)
                    .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem")?)?
            end
        end

        try
            let client = HTTPClient(env.root as AmbientAuth, consume sslctl)
            let dumpMaker = recover val NotifyFactory(this) end
            let req = Payload.request("GET", url)
            req("User-Agent") = "Pony httpget"
            req("Accept") = "application/vnd.twitchtv.v5+json"
            req("Client-ID") = clientId

            let sentreq = client(consume req, dumpMaker)?
        else
            env.exitcode(1)
        end

    be receive(response: Payload val) =>
        _env.out.print(response.status.string())

        try
            for b in response.body()?.values() do
                _env.out.print(b)
            end
        end

class NotifyFactory is HandlerFactory
    let _get: _Get

    new create(get: _Get) =>
        _get = get

    fun apply(session: HTTPSession): HTTPHandler ref^ =>
        HttpNotify(_get, session)

class HttpNotify is HTTPHandler
    let _get: _Get
    let _session: HTTPSession

    new create(get: _Get, session: HTTPSession) =>
        _session = session
        _get = get

    fun apply(response: Payload val) =>
        _get.receive(response)

    fun finished() =>
        _session.dispose()
