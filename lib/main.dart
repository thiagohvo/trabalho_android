import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(LocalizacaoApp());
}

class LocalizacaoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Localização",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainPage(),
    );
  }
}

////////////////////////////////////////////////////////
/// CONTROLADOR DE TELAS
////////////////////////////////////////////////////////

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 0;

  void _navegarPara(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(onNavegar: _navegarPara),
      LocaisPage(),
      PerfilPage(),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.blue,
        onTap: (index) => setState(() => currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Mapa"),
          BottomNavigationBarItem(icon: Icon(Icons.place), label: "Locais"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// TELA 1 - MAPA COM GPS REAL + GOOGLE MAPS
////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  final Function(int) onNavegar;
  HomePage({required this.onNavegar});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _buscaCtrl = TextEditingController();
  final Completer<GoogleMapController> _mapController = Completer();

  List<String> _historico = [];
  Position? _posicaoAtual;
  Set<Marker> _markers = {};
  bool _carregandoGPS = false;

  static const LatLng _posicaoInicial = LatLng(-26.4597, -52.3522); // Clevelândia, PR

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
    _obterLocalizacao();
  }

  // ── GPS ──────────────────────────────────────────

  Future<void> _obterLocalizacao() async {
    setState(() => _carregandoGPS = true);

    bool servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) {
      await _mostrarDialog('Ative o GPS do dispositivo para usar este recurso.');
      Geolocator.openLocationSettings();
      setState(() => _carregandoGPS = false);
      return;
    }

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Permissão de localização negada.')));
        setState(() => _carregandoGPS = false);
        return;
      }
    }
    if (permissao == LocationPermission.deniedForever) {
      await _mostrarDialog('Permissão negada permanentemente. Acesse as configurações do app.');
      Geolocator.openAppSettings();
      setState(() => _carregandoGPS = false);
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final marker = Marker(
      markerId: MarkerId('minha_localizacao'),
      position: LatLng(pos.latitude, pos.longitude),
      infoWindow: InfoWindow(title: 'Você está aqui'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );

    setState(() {
      _posicaoAtual = pos;
      _markers = {marker};
      _carregandoGPS = false;
    });

    // Centraliza o mapa na posição atual
    if (_mapController.isCompleted) {
      final ctrl = await _mapController.future;
      ctrl.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 15,
        ),
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '📍 Localização obtida: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'),
      duration: Duration(seconds: 3),
    ));
  }

  // ── HISTÓRICO ────────────────────────────────────

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dados = prefs.getString('historico');
    if (dados != null) {
      setState(() => _historico = List<String>.from(jsonDecode(dados)));
    }
  }

  Future<void> _salvarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('historico', jsonEncode(_historico));
  }

  void _pesquisar(String texto) {
    if (texto.trim().isEmpty) return;
    setState(() {
      _historico.removeWhere((h) => h == texto.trim());
      _historico.insert(0, texto.trim());
      if (_historico.length > 20) _historico = _historico.sublist(0, 20);
    });
    _salvarHistorico();
    _buscaCtrl.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pesquisando por "$texto"...')),
    );
  }

  void _mostrarHistoricoSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Histórico de Pesquisas",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_historico.isNotEmpty)
                    TextButton(
                      child: Text("Limpar tudo", style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        setState(() => _historico = []);
                        setModalState(() {});
                        await _salvarHistorico();
                      },
                    ),
                ],
              ),
              Divider(),
              _historico.isEmpty
                  ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Nenhuma pesquisa ainda.",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  itemCount: _historico.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: Icon(Icons.history, color: Colors.grey),
                    title: Text(_historico[i]),
                    trailing: IconButton(
                      icon: Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() => _historico.removeAt(i));
                        setModalState(() {});
                        _salvarHistorico();
                      },
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pesquisar(_historico[i]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialog(String msg) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Atenção'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Ok'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // GOOGLE MAPS
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: _posicaoAtual != null
                ? LatLng(_posicaoAtual!.latitude, _posicaoAtual!.longitude)
                : _posicaoInicial,
            zoom: 14,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),

        // BARRA DE BUSCA
        Positioned(
          top: 50,
          left: 15,
          right: 15,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(30),
            child: TextField(
              controller: _buscaCtrl,
              onSubmitted: _pesquisar,
              decoration: InputDecoration(
                hintText: "Buscar local...",
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.history),
                  tooltip: "Ver histórico",
                  onPressed: _mostrarHistoricoSheet,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(15),
              ),
            ),
          ),
        ),

        // BOTÕES FLUTUANTES
        Positioned(
          right: 15,
          bottom: 30,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: "locais_btn",
                backgroundColor: Colors.blue,
                child: Icon(Icons.place, color: Colors.white),
                onPressed: () => widget.onNavegar(1),
                tooltip: "Ver locais",
              ),
              SizedBox(height: 10),
              FloatingActionButton(
                heroTag: "gps_btn",
                backgroundColor: Colors.white,
                child: _carregandoGPS
                    ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location, color: Colors.blue),
                onPressed: _carregandoGPS ? null : _obterLocalizacao,
                tooltip: "Minha localização",
              ),
            ],
          ),
        ),

        // CARD COM COORDENADAS
        if (_posicaoAtual != null)
          Positioned(
            bottom: 30,
            left: 15,
            right: 80,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Localização atual",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'Lat: ${_posicaoAtual!.latitude.toStringAsFixed(5)}\n'
                                'Lng: ${_posicaoAtual!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

////////////////////////////////////////////////////////
/// TELA 2 - LOCAIS (CRUD COMPLETO)
////////////////////////////////////////////////////////

class LocaisPage extends StatefulWidget {
  @override
  _LocaisPageState createState() => _LocaisPageState();
}

class _LocaisPageState extends State<LocaisPage> {
  List<Map<String, String>> locais = [];

  @override
  void initState() {
    super.initState();
    _carregarLocais();
  }

  Future<void> _carregarLocais() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dados = prefs.getString('locais');
    if (dados != null) {
      final List<dynamic> lista = jsonDecode(dados);
      setState(() {
        locais = lista.map((e) => Map<String, String>.from(e)).toList();
      });
    } else {
      setState(() {
        locais = [
          {"nome": "Café Central", "desc": "Ótimo café", "dist": "350 m", "categoria": "Alimentação"},
          {"nome": "Shopping Center", "desc": "Compras e lazer", "dist": "900 m", "categoria": "Compras"},
          {"nome": "Farmácia", "desc": "Aberto 24h", "dist": "600 m", "categoria": "Saúde"},
        ];
      });
      _salvarLocais();
    }
  }

  Future<void> _salvarLocais() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locais', jsonEncode(locais));
  }

  void _abrirDialog({int? index}) {
    final nomeCtrl = TextEditingController(text: index != null ? locais[index]["nome"] : "");
    final descCtrl = TextEditingController(text: index != null ? locais[index]["desc"] : "");
    final distCtrl = TextEditingController(text: index != null ? locais[index]["dist"] : "");
    String categoriaSelecionada = index != null ? (locais[index]["categoria"] ?? "Outro") : "Outro";
    final categorias = ["Alimentação", "Compras", "Saúde", "Lazer", "Serviços", "Outro"];
    final bool editando = index != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editando ? "Editar Local" : "Novo Local"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: InputDecoration(
                      labelText: "Nome *",
                      prefixIcon: Icon(Icons.place),
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                      labelText: "Descrição",
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: distCtrl,
                  decoration: InputDecoration(
                      labelText: "Distância (ex: 500 m)",
                      prefixIcon: Icon(Icons.directions_walk),
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categoriaSelecionada,
                  decoration: InputDecoration(
                      labelText: "Categoria",
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder()),
                  items: categorias
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => categoriaSelecionada = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(child: Text("Cancelar"), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton(
              child: Text(editando ? "Salvar" : "Adicionar"),
              onPressed: () {
                if (nomeCtrl.text.trim().isEmpty) return;
                final novoLocal = {
                  "nome": nomeCtrl.text.trim(),
                  "desc": descCtrl.text.trim(),
                  "dist": distCtrl.text.trim(),
                  "categoria": categoriaSelecionada,
                };
                setState(() {
                  if (editando) {
                    locais[index!] = novoLocal;
                  } else {
                    locais.add(novoLocal);
                  }
                });
                _salvarLocais();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(editando ? "Local atualizado!" : "Local adicionado!"),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deletarLocal(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Remover local"),
        content: Text('Deseja remover "${locais[index]["nome"]}"?'),
        actions: [
          TextButton(child: Text("Cancelar"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text("Excluir", style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() => locais.removeAt(index));
              _salvarLocais();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text("Local removido!")));
            },
          ),
        ],
      ),
    );
  }

  IconData _iconeCategoria(String? cat) {
    switch (cat) {
      case "Alimentação": return Icons.restaurant;
      case "Compras": return Icons.shopping_bag;
      case "Saúde": return Icons.local_hospital;
      case "Lazer": return Icons.park;
      case "Serviços": return Icons.build;
      default: return Icons.location_on;
    }
  }

  Color _corCategoria(String? cat) {
    switch (cat) {
      case "Alimentação": return Colors.orange;
      case "Compras": return Colors.purple;
      case "Saúde": return Colors.red;
      case "Lazer": return Colors.green;
      case "Serviços": return Colors.brown;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Locais"),
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text("${locais.length} salvos",
                  style: TextStyle(color: Colors.grey[600])),
            ),
          )
        ],
      ),
      body: locais.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey),
            SizedBox(height: 10),
            Text("Nenhum local cadastrado.",
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("Adicionar local"),
              onPressed: () => _abrirDialog(),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: locais.length,
        itemBuilder: (context, index) {
          final local = locais[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                _corCategoria(local["categoria"]).withOpacity(0.15),
                child: Icon(_iconeCategoria(local["categoria"]),
                    color: _corCategoria(local["categoria"])),
              ),
              title: Text(local["nome"]!,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(local["desc"]!),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(local["dist"]!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _corCategoria(local["categoria"]).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          local["categoria"] ?? "Outro",
                          style: TextStyle(
                              fontSize: 10,
                              color: _corCategoria(local["categoria"])),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _abrirDialog(index: index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletarLocal(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.add),
        label: Text("Novo Local"),
        onPressed: () => _abrirDialog(),
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// TELA 3 - PERFIL
////////////////////////////////////////////////////////

class PerfilPage extends StatefulWidget {
  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  String nome = "Thiago Oliveira";
  String email = "thiago@email.com";
  String telefone = "";
  List<String> _historico = [];

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
    _carregarHistorico();
  }

  Future<void> _carregarPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nome = prefs.getString('perfil_nome') ?? "Thiago Oliveira";
      email = prefs.getString('perfil_email') ?? "thiago@email.com";
      telefone = prefs.getString('perfil_telefone') ?? "";
    });
  }

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dados = prefs.getString('historico');
    if (dados != null) {
      setState(() => _historico = List<String>.from(jsonDecode(dados)));
    }
  }

  Future<void> _salvarPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('perfil_nome', nome);
    await prefs.setString('perfil_email', email);
    await prefs.setString('perfil_telefone', telefone);
  }

  void _editarPerfil() {
    final nomeCtrl = TextEditingController(text: nome);
    final emailCtrl = TextEditingController(text: email);
    final telCtrl = TextEditingController(text: telefone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Editar Perfil"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: InputDecoration(
                  labelText: "Nome", border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                  labelText: "E-mail", border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              decoration: InputDecoration(
                  labelText: "Telefone", border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(child: Text("Cancelar"), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            child: Text("Salvar"),
            onPressed: () {
              setState(() {
                nome = nomeCtrl.text.trim().isNotEmpty ? nomeCtrl.text.trim() : nome;
                email = emailCtrl.text.trim();
                telefone = telCtrl.text.trim();
              });
              _salvarPerfil();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text("Perfil atualizado!")));
            },
          ),
        ],
      ),
    );
  }

  void _mostrarHistorico() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Histórico de Pesquisas",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Divider(),
            _historico.isEmpty
                ? Expanded(
              child: Center(
                child: Text("Nenhuma pesquisa registrada.",
                    style: TextStyle(color: Colors.grey)),
              ),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: _historico.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: Icon(Icons.history, color: Colors.grey),
                  title: Text(_historico[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil"),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: "Editar perfil",
            onPressed: _editarPerfil,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 55, color: Colors.blue),
                  ),
                  SizedBox(height: 12),
                  Text(nome,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 4),
                  Text(email,
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  if (telefone.isNotEmpty)
                    Text(telefone,
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text("Conta",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[700])),
                  SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.history, color: Colors.orange),
                          title: Text("Histórico de pesquisas"),
                          subtitle: Text("${_historico.length} pesquisas salvas"),
                          trailing: Icon(Icons.chevron_right),
                          onTap: _mostrarHistorico,
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.edit, color: Colors.blue),
                          title: Text("Editar perfil"),
                          trailing: Icon(Icons.chevron_right),
                          onTap: _editarPerfil,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}