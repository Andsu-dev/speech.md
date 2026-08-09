# speech.md

Transcrição de voz no macOS, inteiramente no dispositivo. Sem servidor, sem
conta, sem áudio saindo do seu Mac.

Construído sobre `SpeechAnalyzer` e `SpeechTranscriber` (Apple Speech), com
`ScreenCaptureKit` para capturar o áudio das outras pessoas em uma call.

## O que faz

**Falar** — atalho global em qualquer app: segure, fale, solte, e o texto é
colado onde o cursor estiver. Um toque curto mantém ouvindo até o toque
seguinte.

**Reuniões** — grava a reunião em dois canais separados: seu microfone e o
áudio do sistema, cada um com seu próprio analyzer. A transcrição aparece ao
vivo, lado a lado.

**Arquivos** — arraste um áudio e receba a transcrição, com o fator de
velocidade em múltiplos de tempo real.

**Dicionário** — atalhos de voz: fale "meu email" e saia o endereço completo.

**Markdown** — opcional: um modelo on-device (Foundation Models) reformata o
ditado antes de colar, transformando enumerações em lista e corrigindo
pontuação.

## Desempenho

Medido em Apple M5, macOS 26.5, locale `pt-BR`, modo baixa latência. Áudio de
27,7s gerado com `say`, três execuções.

| Medida | Resultado |
| --- | ---: |
| Transcrição de arquivo | **75× tempo real** (27,7s de áudio em 0,37s) |
| Formatação Markdown, 14 palavras | 0,62s (0,43–0,93) |
| Formatação Markdown, 56 palavras | 1,02s (0,90–1,12) |

A formatação só entra no caminho quando ligada, e roda **depois** da
transcrição — ela adiciona latência entre soltar o atalho e o texto aparecer,
não durante a fala.

O número de tempo real mede throughput de arquivo, não a experiência ao vivo.
As metas para uso contínuo — primeira parcial abaixo de 300 ms e lag sustentado
abaixo de 600 ms — ainda não foram medidas em sessão longa e real.

## Requisitos

- Apple Silicon
- macOS 26 ou superior
- Xcode 26 ou superior

## Build

```sh
./scripts/bundle.sh
open dist/speech.md.app
```

### Assinatura

O script assina com a identidade em `SPEECH_SIGN_IDENTITY` (padrão:
`speech.md Local`). Isso importa mais do que parece: o macOS vincula as
permissões de privacidade à assinatura do app, e uma assinatura ad-hoc
(`codesign --sign -`) gera um hash novo a cada build — o sistema trata cada
rebuild como um app diferente e pede microfone, tela e acessibilidade de novo,
toda vez.

Para criar uma identidade local estável, uma única vez:

```sh
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 \
  -nodes -subj "/CN=speech.md Local" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "basicConstraints=critical,CA:false"
openssl pkcs12 -export -legacy -out cert.p12 -inkey key.pem -in cert.pem \
  -passout pass:senha -name "speech.md Local"
security import cert.p12 -k ~/Library/Keychains/login.keychain-db \
  -P senha -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db cert.pem
```

Ou exporte `SPEECH_SIGN_IDENTITY` com uma identidade Apple Development que você
já tenha.

## Permissões

| Permissão        | Para quê                                  |
| ---------------- | ----------------------------------------- |
| Microfone        | Transcrever a sua voz                     |
| Gravação de tela | Capturar o áudio dos outros participantes |
| Acessibilidade   | Colar o texto ditado no app em foco       |

A gravação de tela só é necessária para o canal "Outros". Desligue "Áudio dos
outros participantes" nas Configurações e a reunião roda apenas com o
microfone, sem essa permissão.

## Arquitetura

```
Sources/SpeechMD/
├── App/          ponto de entrada
├── Speech/       SpeechPipeline, captura de áudio do sistema
├── Dictation/    ditado global e inserção de texto
├── Meetings/     gravação de reunião em dois canais
├── Files/        transcrição de arquivo
├── Snippets/     dicionário de atalhos de voz
├── Island/       indicador flutuante junto ao notch
├── Settings/     preferências, atalho global, permissões
└── Notetaker/    shell da interface
```

A transcrição parcial nunca espera tradução, resumo ou persistência. Esses
consumidores recebem eventos e podem descartar trabalho quando ficam para trás.

## Estado

Projeto pessoal, em desenvolvimento. As reuniões e os ditados vivem em memória
— fechar o app os descarta. Persistência é o próximo passo.

## Licença

MIT — veja [LICENSE](LICENSE).
