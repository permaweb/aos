# hyper AOS

hyper AOS is a hyperBEAM based implementation of AOS, focused to deliver lighting fast performance to the AO network.

## Developer Setup

- Install lua

```sh
wget https://www.lua.org/ftp/lua-5.3.6.tar.gz
tar -xzf lua-5.3.6.tar.gz
cd lua-5.3.6
```

For linux

```sh
make linux
```

For mac

```sh
make macosx
```

```sh
sudo make install
```

- Install luarocks

```sh
wget https://luarocks.org/releases/luarocks-3.9.2.tar.gz
tar -xzf luarocks-3.9.2.tar.gz
cd luarocks-3.9.2
```

```sh
./configure --lua-version=5.3 --with-lua=/usr/local
make
sudo make install
```

- Init lua env

```sh
luarocks init
```

- Install busted testing library

```sh
luarocks install busted
```

- Setup lua env

```sh
eval $(luarocks path)
```

## Tests

- Running Tests

```sh
busted
```

- Writing Tests

Add your test in the `spec` folder and name the test ending with `_spec.lua`
