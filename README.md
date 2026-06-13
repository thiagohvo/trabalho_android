# 📍 Localização App

Aplicativo mobile desenvolvido em Flutter como projeto acadêmico da disciplina de Desenvolvimento Mobile, no curso de Sistemas de Informação — UNIMATER.

O app permite gerenciar locais de interesse, visualizar sua localização em tempo real via GPS e manter um histórico de pesquisas, com persistência de dados local.

---

## 📱 Funcionalidades

### 🗺️ Mapa
- Mapa interativo com **Google Maps**
- Obtenção da **localização em tempo real** via sensor GPS do dispositivo
- Marcador azul indicando a posição atual do usuário
- Card exibindo as coordenadas (latitude e longitude)
- Barra de busca com **histórico de pesquisas persistido**

### 📍 Locais (CRUD completo)
- **Adicionar** novos locais com nome, descrição, distância e categoria
- **Editar** locais existentes
- **Excluir** locais com confirmação
- **Listagem** com ícones e cores por categoria
- Dados salvos localmente — persistem ao fechar e reabrir o app

### 👤 Perfil
- Editar nome, e-mail e telefone
- Visualizar histórico de pesquisas realizadas no mapa
- Dados do perfil salvos localmente

---

## 🛠️ Tecnologias utilizadas

| Tecnologia | Uso |
|---|---|
| [Flutter](https://flutter.dev) | Framework principal |
| [Dart](https://dart.dev) | Linguagem de programação |
| [google_maps_flutter](https://pub.dev/packages/google_maps_flutter) | Exibição do mapa |
| [geolocator](https://pub.dev/packages/geolocator) | Sensor GPS / localização |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | Persistência de dados local |
| Google Maps SDK for Android | API do mapa |

---

## ⚙️ Como rodar o projeto

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado
- Android Studio ou dispositivo Android físico com depuração USB ativa
- Chave de API do Google Maps (Maps SDK for Android)

### 1. Clone o repositório

```bash
git clone https://github.com/seu-usuario/flutter_localizacao.git
cd flutter_localizacao
```

### 2. Instale as dependências

```bash
flutter pub get
```

### 3. Configure a chave da API do Google Maps

Abra o arquivo `android/app/src/main/AndroidManifest.xml` e substitua `SUA_CHAVE_AQUI` pela sua chave:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="SUA_CHAVE_AQUI"/>
```

### 4. Rode no dispositivo Android

Conecte o celular via USB com depuração ativa e execute:

```bash
flutter run
```

---

## 📦 Dependências (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_maps_flutter: ^2.5.0
  geolocator: ^11.0.0
  shared_preferences: ^2.2.2
```

---

## 📁 Estrutura do projeto

```
lib/
└── main.dart        # Código principal com todas as telas
android/
└── app/
    └── src/
        └── main/
            └── AndroidManifest.xml   # Configuração da API Key
```

---

## 🎓 Informações acadêmicas

- **Curso:** Sistemas de Informação
- **Instituição:** Centro Universitário Mater Dei — UNIMATER
- **Disciplina:** Desenvolvimento de Aplicativos Móveis
- **Aluno:** Thiago Oliveira
- **Orientador:** Prof. Giovani Fabris Marcarini
