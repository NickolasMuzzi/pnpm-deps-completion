# pnpm-deps-completion

Autocomplete de dependências do projeto para o pnpm, em **bash** e **zsh**, distribuído como pacote `.deb`.

```console
$ pnpm update @<TAB>
@babel/core    @types/node    @vitejs/plugin-react

$ pnpm rm vit<TAB>      # vitest
$ pnpm exec tsc<TAB>    # tsc (do node_modules/.bin)
```

O pacote também instala o comando `pnpm-deps`, disponível em qualquer lugar do terminal:

```console
$ pnpm-deps doctor
pnpm-deps 1.0.0
helper: /usr/share/pnpm-deps-completion/lib/deps.js
package.json: /home/voce/projeto/package.json (42 dependencias)
node_modules/.bin: /home/voce/projeto/node_modules/.bin (18 binarios)
```

## Instalação

Se fizer fork, troque `NickolasMuzzi` pelo seu usuário no `install.sh`, no `DEBIAN/control` e neste README.

### Via curl (instala o .deb com apt)

```sh
curl -fsSL https://raw.githubusercontent.com/NickolasMuzzi/pnpm-deps-completion/main/install.sh | bash
```

O instalador baixa o `.deb` que está em `dist/`, instala com `apt-get` (pedindo sudo quando necessário) e **não edita** `.bashrc` nem `.zshrc`.

### Via apt, baixando o .deb

```sh
curl -LO https://raw.githubusercontent.com/NickolasMuzzi/pnpm-deps-completion/main/dist/pnpm-deps-completion_1.0.0_all.deb
sudo apt install ./pnpm-deps-completion_1.0.0_all.deb
```

### Sem root

```sh
curl -fsSL https://raw.githubusercontent.com/NickolasMuzzi/pnpm-deps-completion/main/install.sh | bash -s -- --user
```

Nesse modo os arquivos vão para `~/.local/share/pnpm-deps-completion`, o comando para `~/.local/bin` e o instalador adiciona essa pasta ao `PATH` no `~/.profile`. Como ele não pode escrever nos diretórios de completion do sistema, adiciona também um bloco `source` no `.bashrc`/`.zshrc`.

### Sobre o PATH

Não mexemos no `PATH` na instalação via apt: o pacote coloca `pnpm-deps` em `/usr/bin`, que já está no `PATH` de qualquer terminal. O comando `pnpm-deps --version` funciona de qualquer diretório.

## Desinstalação

```sh
sudo apt purge pnpm-deps-completion
```

Para instalação `--user`:

```sh
curl -fsSL .../install.sh | bash -s -- --user --uninstall
# ou, dentro do repo: ./install.sh --user --uninstall
```

Como a instalação via apt não toca arquivos do usuário, não sobra nada no `.bashrc`/`.zshrc`.

## O que é completado

| Comando                                   | Fonte dos nomes                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------------- |
| `update`, `up`, `upgrade`           | `dependencies`, `devDependencies`, `optionalDependencies`, `peerDependencies` |
| `remove`, `rm`, `uninstall`, `un` | mesmas seções                                                                       |
| `why`                                   | mesmas seções                                                                       |
| `exec`, `x`, `pnx`                  | entradas do `node_modules/.bin` mais próximo                                       |

Aliases `pn`/`pnx` também têm completion. O `package.json` é encontrado subindo a partir do diretório atual, então funciona de dentro de `src/`. Em monorepos, entre no diretório do pacote (suporte a `--filter` ainda não está incluído).

## Como funciona

- `/usr/share/bash-completion/completions/pnpm` e `/usr/share/zsh/vendor-completions/_pnpm_deps` são carregados automaticamente pelos shells. Não é preciso `source` manual.
- `lib/deps.js` lê o manifesto mais próximo, junta as quatro seções, deduplica e ordena. Nenhuma rede é consultada.
- Para subcomandos de `pnpm` que não são de dependência, a completion delega para a completion oficial do pnpm (`pnpm completion-server`), se ela existir.
- `/usr/bin/pnpm-deps` é um symlink para o CLI em `/usr/share/pnpm-deps-completion/bin/`.

## Como o pacote é montado

```sh
./build-deb.sh
# gera dist/pnpm-deps-completion_1.0.0_all.deb
```

O `dpkg-deb --build` usa o conteúdo de `packaging/deb/` mais os arquivos do repo. Para instalar o que você acabou de buildar:

```sh
./install.sh --local
```

## Opções do instalador

```sh
./install.sh --dry-run    # mostra os comandos sem executar
./install.sh --local      # constroi o .deb do checkout e instala
./install.sh --user       # instalação sem root
./install.sh --uninstall  # apt purge (ou --user --uninstall)
./install.sh --repo OUTRO-USUARIO/pnpm-deps-completion
```

## Testes

```sh
bash test/test.sh
```

Cobre o helper, os cenários de completion no bash e no zsh, o `.deb` gerado, o CLI e o instalador em modo `--user`.

## Licença

MIT. Veja [LICENSE](LICENSE).
