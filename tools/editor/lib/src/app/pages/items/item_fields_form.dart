import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/item_source.dart';

/// Bounded item schema controls; values remain local until the page validates
/// and dispatches one semantic edit through its plugin.
class ItemFieldsForm extends StatelessWidget {
  const ItemFieldsForm({
    super.key,
    required this.values,
    required this.fields,
    required this.onChanged,
    this.path = 'data',
  });
  final Map<String, dynamic> values;
  final Map<String, ItemField> fields;
  final VoidCallback onChanged;
  final String path;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in fields.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: _field(context, entry.key, entry.value),
        ),
    ],
  );
  Widget _field(BuildContext context, String name, ItemField spec) {
    final key = ValueKey('$path.$name');
    final label = name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    void change(Object? value) {
      if (value == null) {
        values.remove(name);
      } else {
        values[name] = value;
      }
      onChanged();
    }

    if (spec.fields != null) {
      if (spec.isList) {
        final list = (values[name] as List?) ?? [];
        return ExpansionTile(
          key: key,
          title: Text('$label (${list.length})'),
          children: [
            for (var i = 0; i < list.length; i++)
              Card(
                key: ObjectKey(list[i]),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Effect ${i + 1}')),
                          IconButton(
                            tooltip: 'Remove effect',
                            onPressed: () {
                              list.removeAt(i);
                              change(list);
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                      ItemFieldsForm(
                        key: ValueKey(
                          '$path.$name.$i.${list[i]['hook']}.${list[i]['statusProfileId']}',
                        ),
                        values: list[i] as Map<String, dynamic>,
                        fields: spec.fields!,
                        onChanged: onChanged,
                        path: '$path.$name.$i',
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () {
                values[name] = [
                  ...list,
                  {
                    for (final f in spec.fields!.entries)
                      if (f.value.required) f.key: f.value.defaultValue,
                  },
                ];
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add effect'),
            ),
          ],
        );
      }
      final nested = values[name] as Map<String, dynamic>?;
      return ExpansionTile(
        key: key,
        title: Text(label),
        subtitle: Text(nested == null ? 'Inherited defaults' : 'Custom values'),
        children: [
          if (nested == null)
            TextButton(
              onPressed: () => change(<String, dynamic>{}),
              child: Text('Configure $label'),
            )
          else ...[
            ItemFieldsForm(
              values: nested,
              fields: name == 'statusTuning'
                  ? itemTuningFields(values['statusProfileId'] as String)
                  : spec.fields!,
              onChanged: onChanged,
              path: '$path.$name',
            ),
            TextButton(
              onPressed: () => change(null),
              child: const Text('Use defaults'),
            ),
          ],
        ],
      );
    }
    if (spec.choices != null) {
      final current = values[name] ?? (spec.required ? spec.defaultValue : '');
      return DropdownButtonFormField<String>(
        key: ValueKey('${key.value}:$current'),
        initialValue: current as String?,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (!spec.required)
            const DropdownMenuItem(value: '', child: Text('Inherited default')),
          for (final option in spec.choices!)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) => change(value == '' ? null : value),
      );
    }
    if (spec.defaultValue is bool) {
      final current = values[name]?.toString() ?? '';
      return DropdownButtonFormField<String>(
        key: ValueKey('${key.value}:$current'),
        initialValue: current,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: '', child: Text('Inherited default')),
          DropdownMenuItem(value: 'true', child: Text('True')),
          DropdownMenuItem(value: 'false', child: Text('False')),
        ],
        onChanged: (value) => change(value == '' ? null : value == 'true'),
      );
    }
    return TextFormField(
      key: key,
      initialValue: '${values[name] ?? spec.defaultValue ?? ''}',
      decoration: InputDecoration(
        labelText: label,
        helperText:
            '${spec.min}–${spec.max}${name.endsWith('Bp') ? ' bp (100 = 1%)' : ''}; blank inherits default',
      ),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      onChanged: (text) => change(
        text.isEmpty
            ? null
            : spec.integer
            ? int.tryParse(text) ?? text
            : double.tryParse(text) ?? text,
      ),
      validator: (_) {
        final value = values[name];
        if (value == null) return spec.required ? 'A value is required.' : null;
        return value is! num ||
                !value.isFinite ||
                (spec.integer && value is! int) ||
                value < spec.min! ||
                value > spec.max!
            ? 'Enter ${spec.integer ? 'an integer' : 'a number'} from ${spec.min} to ${spec.max}.'
            : null;
      },
    );
  }
}
