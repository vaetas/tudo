import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';
import 'package:tudo_app/common/check.dart';
import 'package:tudo_app/common/drag_handler.dart';
import 'package:tudo_app/common/edit_list.dart';
import 'package:tudo_app/common/empty_page.dart';
import 'package:tudo_app/common/icon_label.dart';
import 'package:tudo_app/common/popup_menu.dart';
import 'package:tudo_app/common/progress.dart';
import 'package:tudo_app/common/share_list.dart';
import 'package:tudo_app/common/text_input_dialog.dart';
import 'package:tudo_app/common/value_builders.dart';
import 'package:tudo_app/extensions.dart';

import 'list_provider.dart';
import 'manage_participants.dart';

const blurSigma = 14.0;

enum ListAction { delete }

class ToDoListPage extends StatelessWidget {
  final ToDoList list;
  final _listKey = GlobalKey<_ToDoListViewState>();
  final _uncheckedListKey = GlobalKey();
  final _controller = ScrollController();

  ToDoListPage({Key? key, required this.list}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottom = max(MediaQuery.of(context).viewInsets.bottom,
        MediaQuery.of(context).viewPadding.bottom);

    return GestureDetector(
      // Close keyboard when tapping a non-focusable area
      onTap: () => FocusScope.of(context).unfocus(),
      child: ValueStreamBuilder<ToDoListWithItems>(
        stream: context.listProvider.getList(list.id),
        initialData: ToDoListWithItems.fromList(list, []),
        errorWidget: Material(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t.listUnavailable,
                style: context.theme.textTheme.headline6,
              ),
              const SizedBox(height: 16),
              MaterialButton(
                child: Text(t.close),
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
        builder: (_, list) => Theme(
          data: context.theme.copyWith(
            colorScheme:
                context.theme.colorScheme.copyWith(primary: list.color),
            primaryColor: list.color,
            primaryTextTheme:
                TextTheme(headline6: TextStyle(color: list.color)),
            primaryIconTheme: IconThemeData(color: list.color),
            iconTheme: IconThemeData(color: list.color),
            toggleableActiveColor: list.color,
            textSelectionTheme: TextSelectionThemeData(
              selectionHandleColor: list.color,
              cursorColor: list.color,
            ),
          ),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: TitleBar(
              list: list,
              actions: [
                IconButton(
                  tooltip: t.share,
                  icon: Icon(Icons.adaptive.share),
                  onPressed: () => shareToDoList(context, list),
                ),
                PopupMenu(
                  entries: [
                    PopupEntry(
                      Icons.edit,
                      t.editList,
                      () => editToDoList(context, list),
                    ),
                    if (list.isShared)
                      PopupEntry(
                        Icons.supervised_user_circle,
                        t.participants,
                        () => editParticipants(context),
                      ),
                    PopupEntry(
                      Icons.exit_to_app,
                      t.leaveList,
                      () => context.pop(ListAction.delete),
                      context.theme.errorColor,
                    ),
                  ],
                ),
              ],
            ),
            body: list.items.isEmpty
                ? EmptyPage(text: t.toDoListEmptyMessage)
                : ToDoListView(
                    key: _listKey,
                    list: list,
                    checkedListKey: _uncheckedListKey,
                    controller: _controller,
                  ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: InputBar(
                // key: inputKey,
                onSubmitted: (value) => _addItem(context, list.id, value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void editParticipants(BuildContext context) =>
      manageParticipants(context, list.id);

  Future<void> _addItem(
      BuildContext context, String listID, String name) async {
    final itemId = await context.listProvider.createItem(list.id, name);

    // Wait for item insertion animation to complete
    await Future.delayed(const Duration(milliseconds: 400));
    _listKey.currentState?.scrollToItem(itemId);
  }
}

class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  final ToDoListWithItems list;
  final List<Widget> actions;

  const TitleBar({Key? key, required this.list, required this.actions})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.theme.primaryColor;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          systemOverlayStyle: context.theme.brightness == Brightness.light
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          foregroundColor: primaryColor,
          centerTitle: true,
          backgroundColor: primaryColor.withAlpha(20),
          elevation: 0,
          leading: InkResponse(
            onTap: () => context.pop(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(
                  left: 8,
                  child: Icon(
                    Icons.arrow_back_ios,
                    size: 16,
                  ),
                ),
                Positioned(
                  right: 4,
                  child: Hero(
                    tag: 'progress_${list.id}',
                    child: Progress(
                      progress: list.doneCount,
                      total: list.itemCount,
                      color: list.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: Column(
            children: [
              Hero(
                tag: 'name_${list.id}',
                child: Text(
                  list.name,
                  style: context.theme.textTheme.headline6,
                ),
              ),
              if (list.isShared)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IconLabel(
                    Icons.supervised_user_circle,
                    list.memberNames(context),
                  ),
                ),
            ],
          ),
          actions: actions,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class InputBar extends StatefulWidget {
  final Function(String value) onSubmitted;

  const InputBar({Key? key, required this.onSubmitted}) : super(key: key);

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: primaryColor,
            style: context.theme.textTheme.subtitle1!
                .copyWith(color: primaryColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: primaryColor.withAlpha(30),
              contentPadding: const EdgeInsets.all(20),
              hintText: context.t.addItem,
              border: InputBorder.none,
              suffixIcon: IconButton(
                padding: const EdgeInsets.only(right: 10),
                icon: const Icon(Icons.add),
                onPressed: _controller.text.isEmpty
                    ? null
                    : () => _onSubmitted(_controller.text),
              ),
            ),
            maxLines: 1,
            onChanged: (_) => setState(() {}),
            onSubmitted: (text) => _onSubmitted(text),
          ),
        ),
      ),
    );
  }

  void _onSubmitted(String text) {
    if (text.isEmpty) return;

    widget.onSubmitted(text);
    _controller.clear();
    _focusNode.requestFocus();
  }
}

class ToDoListView extends StatefulWidget {
  final ToDoListWithItems list;
  final Key checkedListKey;
  final ScrollController controller;

  const ToDoListView({
    Key? key,
    required this.list,
    required this.checkedListKey,
    required this.controller,
  }) : super(key: key);

  @override
  State<ToDoListView> createState() => _ToDoListViewState();
}

class _ToDoListViewState extends State<ToDoListView> {
  final _itemKeys = <String, GlobalKey>{};

  // Temporarily remember deleted items to fix an edge case in the removal anim
  String? _lastDeletedItemId;

  List<ToDo> get items => widget.list.items;

  @override
  Widget build(BuildContext context) {
    final uncheckedItems = items.where((item) => !item.done).toList();
    final checkedItems = items.where((item) => item.done).toList();
    _itemKeys.clear();

    return ListView(
      controller: widget.controller,
      clipBehavior: Clip.none,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ImplicitlyAnimatedReorderableList<ToDo>(
          key: widget.checkedListKey,
          items: uncheckedItems,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          insertDuration: const Duration(milliseconds: 300),
          removeDuration: const Duration(milliseconds: 300),
          reorderDuration: const Duration(milliseconds: 200),
          areItemsTheSame: (oldItem, newItem) => oldItem == newItem,
          onReorderFinished: (_, from, to, __) {
            if (from == to) return;
            _swap(uncheckedItems[from], uncheckedItems[to]);
          },
          itemBuilder: (_, itemAnimation, item, __) => Reorderable(
            key: Key(item.id),
            builder: (context, animation, inDrag) => SizeFadeTransition(
              sizeFraction: 0.7,
              curve: Curves.easeInOut,
              animation: itemAnimation,
              child: _ListTile(
                key: _itemKeys[item.id] ??= GlobalKey(),
                item: item,
                onToggle: () => _toggle(item),
                onEdit: () => _editItem(item),
                onDelete: () => _deleteItem(item),
                isDeleted: item.id == _lastDeletedItemId,
                isShared: widget.list.isShared,
              ),
            ),
          ),
        ),
        ImplicitlyAnimatedList<ToDo>(
          items: [
            if (checkedItems.isNotEmpty)
              ToDo('header', '', false, null, '', 0, null, null),
            ...checkedItems,
          ],
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          areItemsTheSame: (oldItem, newItem) => oldItem == newItem,
          itemBuilder: (context, itemAnimation, item, i) => SizeFadeTransition(
            sizeFraction: 0.7,
            curve: Curves.easeInOut,
            animation: itemAnimation,
            child: item.id == 'header'
                ? _CompletedHeader(
                    onClear: _clearCompleted,
                  )
                : _ListTile(
                    item: item,
                    onToggle: () => _toggle(item),
                    onEdit: () => _editItem(item),
                    onDelete: () => _deleteItem(item),
                    isDeleted: item.id == _lastDeletedItemId,
                    isShared: widget.list.isShared,
                  ),
          ),
        ),
      ],
    );
  }

  void scrollToItem(String id) {
    final itemContext = _itemKeys[id]?.currentContext;
    if (itemContext != null) {
      Scrollable.ensureVisible(
        itemContext,
        duration: const Duration(milliseconds: 300),
        alignment: 0.90,
      );
    }
  }

  void _toggle(ToDo toDo) => context.listProvider.setDone(toDo.id, !toDo.done);

  Future<void> _editItem(ToDo toDo) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => TextInputDialog(
        title: context.t.editItem,
        value: toDo.name,
        positiveLabel: context.t.update,
      ),
    );
    if (title != null) {
      context.listProvider.setItemName(toDo.id, title);
    }
  }

  void _deleteItem(ToDo toDo) {
    // Used to hide the item during its removal animation
    _lastDeletedItemId = toDo.id;

    final listProvider = context.listProvider;
    listProvider.deleteItem(toDo.id);

    context.showSnackBar(
      context.t.itemDeleted(toDo.name),
      () {
        _lastDeletedItemId = null;
        listProvider.undeleteItem(toDo.id);
      },
    );
  }

  Future<void> _clearCompleted() async {
    var checked = items.where((item) => item.done).toList();
    if (checked.isEmpty) return;

    var indexes =
        checked.map((e) => context.listProvider.deleteItem(e.id)).toList();

    // Insert in reverse order when undoing so the old indexes match
    checked = checked.reversed.toList();
    indexes = indexes.reversed.toList();
    final count = checked.length;

    context.showSnackBar(
      context.t.itemsCleared(count),
      () {
        for (var i = 0; i < checked.length; i++) {
          final item = checked[i];
          context.listProvider.undeleteItem(item.id);
        }
      },
    );
  }

  void _swap(ToDo from, ToDo to) {
    final fromIndex = items.indexOf(from);
    final toIndex = items.indexOf(to);

    // Copy list
    final itemsCopy = items.toList();
    final item = itemsCopy.removeAt(fromIndex);
    itemsCopy.insert(toIndex, item);
    context.listProvider.setItemOrder(itemsCopy);
  }
}

class _ListTile extends StatelessWidget {
  final ToDo item;
  final Function() onToggle;
  final Function() onEdit;
  final Function() onDelete;
  final bool isDeleted;
  final bool isShared;

  const _ListTile({
    Key? key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleted,
    required this.isShared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDeleted ? 0 : 1,
      child: Dismissible(
        key: Key(item.id),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
        ),
        onDismissed: (_) {
          // Do nothing - deletions happen in confirmDismiss
        },
        confirmDismiss: (_) async {
          // Avoid conflicts between Dismissible and list animations
          // This removes the item and returns true so this widget remains in the
          // tree to be removed by the list animation rather than itself.
          onDelete();
          return false;
        },
        child: ListTile(
          leading: Check(
            checked: item.done,
            onChanged: onToggle,
          ),
          title: Text(item.name),
          subtitle: isShared && item.done
              ? IconLabel(
                  Icons.account_circle, item.doneBy ?? context.t.anonymous)
              : null,
          trailing: item.done
              ? item.doneAt != null
                  ? Text(
                      item.doneAt!.toRelativeString(context),
                      style: context.theme.textTheme.caption,
                    )
                  : null
              : const DragHandle(),
          onTap: () => onToggle(),
          onLongPress: onEdit,
        ),
      ),
    );
  }
}

class _CompletedHeader extends StatelessWidget {
  final Function() onClear;

  const _CompletedHeader({Key? key, required this.onClear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = context.theme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: color.withOpacity(0.4),
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 16, top: 8, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t.completed,
              style: context.theme.textTheme.subtitle2!.copyWith(color: color),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
