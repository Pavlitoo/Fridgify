import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../product_model.dart';
import '../translations.dart';

class ProductListItem extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;
  final Function(Product) onEdit;
  final Function(Product) onShop;
  final Function(Product) onEaten;
  final Function(Product) onDelete;
  final dynamic categoryData; // CategoryData type from fridge_screen

  const ProductListItem({
    super.key,
    required this.product,
    required this.isSelected,
    required this.cardColor,
    required this.textColor,
    required this.onTap,
    required this.onEdit,
    required this.onShop,
    required this.onEaten,
    required this.onDelete,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = product.daysLeft < 3 ? Colors.orange : Colors.green;
    String timeLeftText = product.daysLeft < 30
        ? "${product.daysLeft} ${AppText.get('u_days')}"
        : "${(product.daysLeft / 30).floor()} ${AppText.get('u_months')}";

    return Card(
      color: isSelected ? Colors.green.shade100 : cardColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isSelected ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none
      ),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: categoryData.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(categoryData.icon, color: categoryData.color, size: 28)
            ),
            title: Row(
                children: [
                  Expanded(
                      child: Text(
                          product.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isSelected ? Colors.black : textColor)
                      )
                  ),
                  const SizedBox(width: 8),
                  Text("(${product.quantity} ${AppText.get('u_${product.unit}') ?? product.unit})",
                      style: const TextStyle(color: Colors.grey, fontSize: 14))
                ]
            ),
            subtitle: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(timeLeftText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14))
                ]
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: cardColor,
              onSelected: (value) {
                if (value == 'edit') onEdit(product);
                else if (value == 'shop') onShop(product);
                else if (value == 'eaten') onEaten(product);
                else if (value == 'delete') onDelete(product);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, color: Colors.blue), const SizedBox(width: 10), Text(AppText.get('edit_product'), style: TextStyle(color: textColor))])),
                PopupMenuItem(value: 'eaten', child: Row(children: [const Icon(Icons.restaurant, color: Colors.green), const SizedBox(width: 10), Text(AppText.get('action_eaten'), style: TextStyle(color: textColor))])),
                PopupMenuItem(value: 'shop', child: Row(children: [const Icon(Icons.shopping_cart, color: Colors.orange), const SizedBox(width: 10), Text(AppText.get('yes_list'), style: TextStyle(color: textColor))])),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, color: Colors.red), const SizedBox(width: 10), Text(AppText.get('no_delete'), style: TextStyle(color: textColor))])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}