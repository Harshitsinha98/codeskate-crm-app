import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/crm_api.dart';
import '../widgets/common_sheets.dart';
import '../widgets/premium.dart';

/// Product catalogue used by the WhatsApp AI agent (/api/v1/ai/catalogue).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  String _q = '';

  String get _orgId => context.read<AuthProvider>().user!.activeOrgId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([ProductsApi.list(_orgId), ProductsApi.stats(_orgId)]);
      if (mounted) setState(() {
        _items = r[0] as List<Map<String, dynamic>>;
        _stats = r[1] as Map<String, dynamic>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? p]) async {
    final name = TextEditingController(text: p?['name']?.toString() ?? '');
    final price = TextEditingController(text: p?['price']?.toString() ?? '');
    final category = TextEditingController(text: p?['category']?.toString() ?? 'general');
    final material = TextEditingController(text: p?['material']?.toString() ?? '');
    final image = TextEditingController(text: p?['imageUrl']?.toString() ?? '');
    final desc = TextEditingController(text: p?['description']?.toString() ?? '');
    final tags = TextEditingController(text: ((p?['tags'] as List?) ?? []).join(', '));
    final sku = TextEditingController(text: p?['sku']?.toString() ?? '');
    bool inStock = p?['inStock'] != false;
    bool active = p?['active'] != false;
    double priority = ((p?['priority'] as num?) ?? 50).toDouble().clamp(0, 100);
    bool busy = false;

    await showPremiumSheet(
      context,
      title: p == null ? 'Add product' : 'Edit product',
      subtitle: 'The AI agent recommends products customers ask about',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (image.text.startsWith('http'))
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(imageUrl: image.text, height: 150, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink()),
            ),
          const FieldLabel('Name'),
          TextField(controller: name, decoration: const InputDecoration(hintText: 'Product name')),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Price (₹)'),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], decoration: const InputDecoration(hintText: '0')),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Category'),
                TextField(controller: category, decoration: const InputDecoration(hintText: 'general')),
              ]),
            ),
          ]),
          const FieldLabel('Image URL'),
          TextField(controller: image, onChanged: (_) => setS(() {}), decoration: const InputDecoration(hintText: 'https://…')),
          const FieldLabel('Description'),
          TextField(controller: desc, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'What should the AI tell customers?')),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const FieldLabel('Material'), TextField(controller: material)])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const FieldLabel('SKU'), TextField(controller: sku)])),
          ]),
          const FieldLabel('Tags (comma separated)'),
          TextField(controller: tags, decoration: const InputDecoration(hintText: 'bestseller, festive')),
          FieldLabel('Recommendation priority · ${priority.round()}'),
          Slider(value: priority, min: 0, max: 100, divisions: 20, activeColor: AppColors.primary, onChanged: (v) => setS(() => priority = v)),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('In stock'), value: inStock, onChanged: (v) => setS(() => inStock = v)),
          if (p != null) SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Visible to AI'), value: active, onChanged: (v) => setS(() => active = v)),
          const SizedBox(height: 14),
          GlowButton(
            label: p == null ? 'Add product' : 'Save changes',
            loading: busy,
            onPressed: () async {
              if (name.text.trim().isEmpty || double.tryParse(price.text) == null) return AppToast.error(context, 'Name and price are required');
              setS(() => busy = true);
              final body = {
                'name': name.text.trim(),
                'price': double.parse(price.text),
                'category': category.text.trim().isEmpty ? 'general' : category.text.trim().toLowerCase(),
                'material': material.text.trim(),
                'imageUrl': image.text.trim(),
                'description': desc.text.trim(),
                'tags': tags.text.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList(),
                'sku': sku.text.trim(),
                'inStock': inStock,
                'priority': priority.round(),
                if (p != null) 'active': active,
              };
              try {
                p == null ? await ProductsApi.create(_orgId, body) : await ProductsApi.update(_orgId, p['id'].toString(), body);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) AppToast.success(context, p == null ? 'Product added' : 'Product saved');
                _load();
              } on ApiException catch (e) {
                setS(() => busy = false);
                AppToast.error(context, e.message);
              }
            },
          ),
          if (p != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final ok = await confirmAction(context, title: 'Delete product?', message: '"${p['name']}" will be removed from the catalogue.', destructive: true, confirmLabel: 'Delete');
                if (!ok) return;
                try {
                  await ProductsApi.delete(_orgId, p['id'].toString());
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } on ApiException catch (e) {
                  AppToast.error(context, e.message);
                }
              },
              child: const Text('Delete product', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _items.where((p) => _q.isEmpty || '${p['name']}'.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: PremiumAppBar(title: 'Product catalogue', subtitle: '${_stats['total'] ?? _items.length} products · ${_stats['inStock'] ?? '-'} in stock'),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('Add product')),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? PremiumEmpty(icon: Icons.cloud_off_rounded, title: 'Could not load products', message: _error)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6), child: SearchField(hint: 'Search products', onChanged: (v) => setState(() => _q = v)))),
                    if (list.isEmpty)
                      const SliverFillRemaining(hasScrollBody: false, child: PremiumEmpty(icon: Icons.inventory_2_rounded, title: 'No products yet', message: 'Add products so the AI agent can recommend them on WhatsApp.'))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
                          delegate: SliverChildBuilderDelegate((_, i) {
                            final p = list[i];
                            final img = '${p['imageUrl'] ?? ''}';
                            return PremiumCard(
                              onTap: () => _edit(p),
                              padding: EdgeInsets.zero,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                                    child: Container(
                                      width: double.infinity,
                                      color: AppColors.cream200,
                                      child: img.startsWith('http')
                                          ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: AppColors.textTertiary))
                                          : const Icon(Icons.inventory_2_rounded, size: 36, color: AppColors.orange300),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(11),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(inr((p['price'] as num?) ?? 0), style: AppText.mono(size: 13, color: AppColors.primaryDark)),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Flexible(child: Pill(label: '${p['category'] ?? 'general'}', color: AppColors.signal)),
                                      const Spacer(),
                                      Icon(p['inStock'] == false ? Icons.remove_shopping_cart_rounded : Icons.check_circle_rounded, size: 15, color: p['inStock'] == false ? AppColors.error : AppColors.success),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ).stagger(i);
                          }, childCount: list.length),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
