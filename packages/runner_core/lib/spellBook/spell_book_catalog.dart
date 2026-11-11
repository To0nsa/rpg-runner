import 'spell_book_id.dart';
import 'spell_book_def.dart';
import 'spell_book_data.generated.dart';

/// Typed runtime definitions compiled from the single item authoring source.
class SpellBookCatalog {
  const SpellBookCatalog();
  SpellBookDef get(SpellBookId id) => authoredSpellBookIdDefinitions[id]!;
  SpellBookDef? tryGet(SpellBookId id) => authoredSpellBookIdDefinitions[id];
}
