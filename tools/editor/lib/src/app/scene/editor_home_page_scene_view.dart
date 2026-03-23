part of '../editor_home_page.dart';

extension _EditorHomePageSceneView on _EditorHomePageState {
  Widget _buildViewportPanel(ColliderEntry? selectedEntry) {
    if (selectedEntry == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No collider entry selected.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final scene = widget.controller.colliderScene;
            final runtimeGridCellSize = _runtimeGridCellSize(scene);
            final previewEntry = _previewEntry(selectedEntry);
            final scale =
                _computeViewportScale(viewportSize, previewEntry) *
                _viewportZoom;
            final activeHandle = _dragSession?.entryId == selectedEntry.id
                ? _dragSession!.handle
                : null;
            final zoomLabel = _viewportZoom.toStringAsFixed(2);
            final resolvedReference = _showReferenceLayer
                ? _resolveReferenceVisual(previewEntry)
                : null;
            final referenceAnimKey = resolvedReference == null
                ? null
                : _effectiveReferenceAnimKey(resolvedReference);
            final referenceAnimView = resolvedReference == null
                ? null
                : _effectiveReferenceAnimView(resolvedReference);
            if (referenceAnimView != null) {
              unawaited(
                _ensureReferenceImageLoaded(referenceAnimView.absolutePath),
              );
            }
            final resolvedImage = referenceAnimView == null
                ? null
                : _referenceImageCache[referenceAnimView.absolutePath];
            final referenceAssetPath = previewEntry.referenceVisual?.assetPath;
            final referenceRow = referenceAnimView == null
                ? 0
                : _effectiveReferenceRow(referenceAnimView);
            final referenceFrame = referenceAnimView == null
                ? 0
                : _effectiveReferenceFrame(referenceAnimView);
            final referenceStatusText = referenceAssetPath == null
                ? 'No reference visual metadata'
                : resolvedReference == null
                ? 'Missing reference: assets/images/$referenceAssetPath'
                : referenceAnimView == null
                ? 'Reference metadata has no valid anim key source'
                : _referenceImageFailed.contains(referenceAnimView.absolutePath)
                ? 'Failed loading reference: ${referenceAnimView.displayPath}'
                : resolvedImage == null
                ? 'Loading reference: ${referenceAnimView.displayPath}'
                : 'Reference: ${referenceAnimView.displayPath} '
                      '(key ${referenceAnimKey ?? '-'}, row $referenceRow, '
                      'frame $referenceFrame)';
            final referenceForMetrics = previewEntry.referenceVisual;
            final hasReferenceMetadata = referenceForMetrics != null;
            final hasExplicitAnchor =
                referenceForMetrics?.anchorXPx != null ||
                referenceForMetrics?.anchorYPx != null;
            final resolvedFrameWidth =
                referenceForMetrics != null &&
                    referenceForMetrics.frameWidth != null &&
                    referenceForMetrics.frameWidth! > 0
                ? referenceForMetrics.frameWidth!
                : math.max(1.0, previewEntry.halfX * 2.0);
            final resolvedFrameHeight =
                referenceForMetrics != null &&
                    referenceForMetrics.frameHeight != null &&
                    referenceForMetrics.frameHeight! > 0
                ? referenceForMetrics.frameHeight!
                : math.max(1.0, previewEntry.halfY * 2.0);
            final resolvedAnchorXPx = hasReferenceMetadata
                ? _normalizeReferenceAnchor(
                        referenceForMetrics.anchorXPx,
                        resolvedFrameWidth,
                      ) *
                      resolvedFrameWidth
                : null;
            final resolvedAnchorYPx = hasReferenceMetadata
                ? _normalizeReferenceAnchor(
                        referenceForMetrics.anchorYPx,
                        resolvedFrameHeight,
                      ) *
                      resolvedFrameHeight
                : null;
            final colliderAnchorDeltaWorld = Offset(
              previewEntry.offsetX,
              previewEntry.offsetY,
            );
            final colliderAnchorDeltaPixels = Offset(
              colliderAnchorDeltaWorld.dx * scale,
              colliderAnchorDeltaWorld.dy * scale,
            );
            final metricsText =
                'Offset(world): (${previewEntry.offsetX.toStringAsFixed(2)}, '
                '${previewEntry.offsetY.toStringAsFixed(2)}) | '
                'Anchor(px): '
                '${resolvedAnchorXPx == null || resolvedAnchorYPx == null ? 'n/a' : '(${resolvedAnchorXPx.toStringAsFixed(2)}, '
                          '${resolvedAnchorYPx.toStringAsFixed(2)}) '
                          '[${hasExplicitAnchor ? 'explicit' : 'default center'}]'}'
                ' | Collider-anchor delta: '
                'world (${colliderAnchorDeltaWorld.dx.toStringAsFixed(2)}, '
                '${colliderAnchorDeltaWorld.dy.toStringAsFixed(2)}) / '
                'px (${colliderAnchorDeltaPixels.dx.toStringAsFixed(2)}, '
                '${colliderAnchorDeltaPixels.dy.toStringAsFixed(2)})';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Scene View',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _applyZoomDelta(0.12),
                        icon: const Icon(Icons.zoom_in, size: 18),
                        label: const Text('Zoom In'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _applyZoomDelta(-0.12),
                        icon: const Icon(Icons.zoom_out, size: 18),
                        label: const Text('Zoom Out'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: _resetViewportTransform,
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                        label: Text('Reset View ($zoomLabel x)'),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: DropdownButton<String>(
                          value: _snapMenuValue,
                          isDense: true,
                          items: [
                            DropdownMenuItem(
                              value: 'off',
                              child: Text('Snap: Off'),
                            ),
                            DropdownMenuItem(
                              value: '1x',
                              child: Text(
                                'Snap: 1x (${runtimeGridCellSize.toStringAsFixed(2)})',
                              ),
                            ),
                            DropdownMenuItem(
                              value: '1/2x',
                              child: Text(
                                'Snap: 1/2x (${(runtimeGridCellSize * 0.5).toStringAsFixed(2)})',
                              ),
                            ),
                            DropdownMenuItem(
                              value: '1/4x',
                              child: Text(
                                'Snap: 1/4x (${(runtimeGridCellSize * 0.25).toStringAsFixed(2)})',
                              ),
                            ),
                            DropdownMenuItem(
                              value: '1/8x',
                              child: Text(
                                'Snap: 1/8x (${(runtimeGridCellSize * 0.125).toStringAsFixed(2)})',
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            _updateState(() {
                              _snapFactor = switch (value) {
                                'off' => null,
                                '1x' => 1.0,
                                '1/2x' => 0.5,
                                '1/4x' => 0.25,
                                '1/8x' => 0.125,
                                _ => _snapFactor,
                              };
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: Chip(
                          label: Text(
                            'Grid ${runtimeGridCellSize.toStringAsFixed(2)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: FilterChip(
                          selected: _showReferenceLayer,
                          label: const Text('Reference'),
                          onSelected: (selected) {
                            _updateState(() {
                              _showReferenceLayer = selected;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: FilterChip(
                          selected: _showReferencePoints,
                          label: const Text('Ref Points'),
                          onSelected: (selected) {
                            _updateState(() {
                              _showReferencePoints = selected;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: DropdownButton<double>(
                          value: _referenceOpacity,
                          isDense: true,
                          items: const [
                            DropdownMenuItem<double>(
                              value: 1.0,
                              child: Text('Ref Opacity: 100%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.2,
                              child: Text('Ref Opacity: 20%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.35,
                              child: Text('Ref Opacity: 35%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.45,
                              child: Text('Ref Opacity: 45%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.6,
                              child: Text('Ref Opacity: 60%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.8,
                              child: Text('Ref Opacity: 80%'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            _updateState(() {
                              _referenceOpacity = value;
                            });
                          },
                        ),
                      ),
                      if (resolvedReference != null) ...[
                        if (referenceAnimKey != null &&
                            resolvedReference.animKeys.length > 1) ...[
                          const SizedBox(width: 6),
                          Center(
                            child: DropdownButton<String>(
                              value: referenceAnimKey,
                              isDense: true,
                              items: [
                                for (final key in resolvedReference.animKeys)
                                  DropdownMenuItem<String>(
                                    value: key,
                                    child: Text('Anim: $key'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                _selectReferenceAnimKey(
                                  resolvedReference,
                                  value,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                      if (referenceAnimView != null) ...[
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceRow(referenceAnimView, -1);
                            },
                            icon: const Icon(Icons.remove, size: 16),
                            label: Text('Row $referenceRow'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceRow(referenceAnimView, 1);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Row +'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceFrame(referenceAnimView, -1);
                            },
                            icon: const Icon(Icons.remove, size: 16),
                            label: Text('Frame $referenceFrame'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceFrame(referenceAnimView, 1);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Frame +'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _resetReferenceFrameSelection();
                            },
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text('Ref Reset'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '$referenceStatusText | drag handles edit | drag empty area '
                  'pans | wheel zoom | arrows nudge offsets | Alt+arrows '
                  'nudge extents',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '$metricsText | markers: C collider center, A anchor, '
                  'F frame center, R right extent, T top extent',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (event.scrollDelta.dy < 0) {
                          _applyZoomDelta(0.08);
                        } else if (event.scrollDelta.dy > 0) {
                          _applyZoomDelta(-0.08);
                        }
                      }
                    },
                    child: Focus(
                      focusNode: _viewportFocusNode,
                      onFocusChange: (_) {
                        _updateState(() {});
                      },
                      onKeyEvent: (node, event) {
                        return _handleViewportKeyEvent(event, selectedEntry);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _viewportFocusNode.requestFocus();
                        },
                        onPanStart: (details) {
                          _viewportFocusNode.requestFocus();
                          _startViewportInteraction(
                            selectedEntry,
                            previewEntry,
                            viewportSize,
                            scale,
                            details.localPosition,
                          );
                        },
                        onPanUpdate: (details) {
                          _updateViewportInteraction(details.localPosition);
                        },
                        onPanEnd: (_) {
                          _finishViewportInteraction();
                        },
                        onPanCancel: _cancelViewportInteraction,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _viewportFocusNode.hasFocus
                                  ? const Color(0xFF7CE5FF)
                                  : const Color(0xFF1B2A36),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: Color(0xFF111A22)),
                              ),
                              CustomPaint(
                                painter: _ColliderViewportPainter(
                                  entry: previewEntry,
                                  scale: scale,
                                  gridCellSize: runtimeGridCellSize,
                                  panPixels: _viewportPanPixels,
                                  activeHandle: null,
                                  drawGridAndAxes: true,
                                  drawColliderFill: true,
                                  drawColliderOutline: false,
                                  drawHandles: false,
                                  fillColor:
                                      resolvedReference != null &&
                                          _showReferenceLayer
                                      ? const Color(0x1F22D3EE)
                                      : const Color(0x5522D3EE),
                                ),
                              ),
                              if (resolvedReference != null &&
                                  referenceAnimView != null &&
                                  resolvedImage != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: _referenceOpacity,
                                      child: CustomPaint(
                                        painter: _ReferenceFramePainter(
                                          image: resolvedImage,
                                          row: referenceRow,
                                          frame: referenceFrame,
                                          destinationRect: _referenceRect(
                                            scale: scale,
                                            viewportSize: viewportSize,
                                            reference: resolvedReference,
                                          ),
                                          anchorX: resolvedReference.anchorX,
                                          anchorY: resolvedReference.anchorY,
                                          showReferencePoints:
                                              _showReferencePoints,
                                          frameWidth:
                                              resolvedReference.frameWidth,
                                          frameHeight:
                                              resolvedReference.frameHeight,
                                          gridColumns: referenceAnimView
                                              .defaultGridColumns,
                                          drawMarkerLabels: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              CustomPaint(
                                painter: _ColliderViewportPainter(
                                  entry: previewEntry,
                                  scale: scale,
                                  gridCellSize: runtimeGridCellSize,
                                  panPixels: _viewportPanPixels,
                                  activeHandle: activeHandle,
                                  drawGridAndAxes: false,
                                  drawColliderFill: false,
                                  drawColliderOutline: true,
                                  drawHandles: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  ColliderEntry _previewEntry(ColliderEntry selectedEntry) {
    if (_draftEntryId != selectedEntry.id) {
      return selectedEntry;
    }
    return selectedEntry.copyWith(
      halfX: _draftHalfX,
      halfY: _draftHalfY,
      offsetX: _draftOffsetX,
      offsetY: _draftOffsetY,
    );
  }

  double _computeViewportScale(Size size, ColliderEntry entry) {
    final minSide = math.max(1.0, math.min(size.width, size.height));
    const viewportPadding = 28.0;
    final usableSide = math.max(1.0, minSide - viewportPadding * 2);
    final maxWorldSpan = math.max(
      24.0,
      math.max(
        entry.halfX + entry.offsetX.abs(),
        entry.halfY + entry.offsetY.abs(),
      ),
    );
    return usableSide / (maxWorldSpan * 2.0);
  }

  double _runtimeGridCellSize(ColliderScene? scene) {
    final raw = scene?.runtimeGridCellSize;
    if (raw == null || !raw.isFinite || raw <= 0) {
      return _EditorHomePageState._fallbackRuntimeGridCellSize;
    }
    return raw;
  }

  String get _snapMenuValue {
    final factor = _snapFactor;
    if (factor == null) {
      return 'off';
    }
    return switch (factor) {
      1.0 => '1x',
      0.5 => '1/2x',
      0.25 => '1/4x',
      0.125 => '1/8x',
      _ => '1/4x',
    };
  }

  double _snapValue(double value) {
    final step = _resolvedSnapStep();
    if (step == null || step <= 0) {
      return value;
    }
    return (value / step).roundToDouble() * step;
  }

  double _snapHalfExtent(double value) =>
      math.max(_EditorHomePageState._viewportMinHalfExtent, _snapValue(value));

  double? _resolvedSnapStep() {
    final factor = _snapFactor;
    if (factor == null || factor <= 0) {
      return null;
    }
    return _runtimeGridCellSize(widget.controller.colliderScene) * factor;
  }

  _ResolvedReferenceVisual? _resolveReferenceVisual(ColliderEntry entry) {
    final reference = entry.referenceVisual;
    final workspace = widget.controller.workspace;
    if (reference == null || workspace == null) {
      return null;
    }

    final frameWidth = reference.frameWidth;
    final frameHeight = reference.frameHeight;
    final resolvedFrameWidth = frameWidth != null && frameWidth > 0
        ? frameWidth
        : math.max(1.0, entry.halfX * 2.0);
    final resolvedFrameHeight = frameHeight != null && frameHeight > 0
        ? frameHeight
        : math.max(1.0, entry.halfY * 2.0);
    final resolvedRenderScale =
        reference.renderScale != null && reference.renderScale! > 0
        ? reference.renderScale!
        : 1.0;
    final resolvedAnchorX = _normalizeReferenceAnchor(
      reference.anchorXPx,
      resolvedFrameWidth,
    );
    final resolvedAnchorY = _normalizeReferenceAnchor(
      reference.anchorYPx,
      resolvedFrameHeight,
    );

    _ResolvedReferenceAnimView? resolveAnimView({
      required String key,
      required String assetPath,
      required int row,
      required int frameStart,
      required int? frameCount,
      required int? gridColumns,
    }) {
      final normalizedAssetPath = assetPath.replaceAll('\\', '/');
      final relativeImagePath = 'assets/images/$normalizedAssetPath';
      final absoluteImagePath = workspace.resolve(relativeImagePath);
      final file = File(absoluteImagePath);
      if (!file.existsSync()) {
        return null;
      }
      return _ResolvedReferenceAnimView(
        key: key,
        absolutePath: absoluteImagePath,
        displayPath: relativeImagePath.replaceAll('\\', '/'),
        defaultRow: row,
        defaultFrameStart: frameStart,
        defaultFrameCount: frameCount,
        defaultGridColumns: gridColumns,
      );
    }

    final animViewsByKey = <String, _ResolvedReferenceAnimView>{};
    if (reference.animViewsByKey.isNotEmpty) {
      for (final animView in reference.animViewsByKey.values) {
        final resolvedView = resolveAnimView(
          key: animView.key,
          assetPath: animView.assetPath,
          row: animView.row,
          frameStart: animView.frameStart,
          frameCount: animView.frameCount,
          gridColumns: animView.gridColumns,
        );
        if (resolvedView != null) {
          animViewsByKey[animView.key] = resolvedView;
        }
      }
    } else {
      final fallbackKey = reference.defaultAnimKey ?? 'idle';
      final fallbackView = resolveAnimView(
        key: fallbackKey,
        assetPath: reference.assetPath,
        row: reference.defaultRow,
        frameStart: reference.defaultFrameStart,
        frameCount: reference.defaultFrameCount,
        gridColumns: reference.defaultGridColumns,
      );
      if (fallbackView != null) {
        animViewsByKey[fallbackKey] = fallbackView;
      }
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }

    return _ResolvedReferenceVisual(
      frameWidth: resolvedFrameWidth,
      frameHeight: resolvedFrameHeight,
      renderScale: resolvedRenderScale,
      anchorX: resolvedAnchorX,
      anchorY: resolvedAnchorY,
      defaultAnimKey: reference.defaultAnimKey,
      animViewsByKey: animViewsByKey,
    );
  }

  double _normalizeReferenceAnchor(double? anchorPx, double frameSize) {
    if (anchorPx == null || !anchorPx.isFinite || frameSize <= 0) {
      return 0.5;
    }
    return (anchorPx / frameSize).clamp(0.0, 1.0);
  }

  String? _effectiveReferenceAnimKey(_ResolvedReferenceVisual reference) {
    return reference.resolveAnimKey(_referenceAnimKeyOverride);
  }

  _ResolvedReferenceAnimView? _effectiveReferenceAnimView(
    _ResolvedReferenceVisual reference,
  ) {
    final key = _effectiveReferenceAnimKey(reference);
    if (key == null) {
      return null;
    }
    return reference.animViewsByKey[key];
  }

  int _effectiveReferenceRow(_ResolvedReferenceAnimView reference) {
    final row = _referenceRowOverride ?? reference.defaultRow;
    return row < 0 ? 0 : row;
  }

  int _effectiveReferenceFrame(_ResolvedReferenceAnimView reference) {
    final fallback = reference.defaultFrameStart;
    final value = _referenceFrameOverride ?? fallback;
    final minFrame = reference.defaultFrameStart;
    final maxFrame = reference.maxFrameIndex ?? 9999;
    return value.clamp(minFrame, maxFrame);
  }

  void _selectReferenceAnimKey(_ResolvedReferenceVisual reference, String key) {
    final resolvedKey = reference.resolveAnimKey(key);
    if (resolvedKey == null) {
      return;
    }
    _updateState(() {
      _referenceAnimKeyOverride = resolvedKey;
      _referenceRowOverride = null;
      _referenceFrameOverride = null;
    });
  }

  void _adjustReferenceRow(_ResolvedReferenceAnimView reference, int delta) {
    final next = math.max(0, _effectiveReferenceRow(reference) + delta);
    _updateState(() {
      _referenceRowOverride = next;
    });
  }

  void _adjustReferenceFrame(_ResolvedReferenceAnimView reference, int delta) {
    final minFrame = reference.defaultFrameStart;
    final maxFrame = reference.maxFrameIndex ?? 9999;
    final next = (_effectiveReferenceFrame(reference) + delta).clamp(
      minFrame,
      maxFrame,
    );
    _updateState(() {
      _referenceFrameOverride = next;
    });
  }

  void _resetReferenceFrameSelection() {
    _updateState(() {
      _referenceRowOverride = null;
      _referenceFrameOverride = null;
    });
  }

  Future<void> _ensureReferenceImageLoaded(String absolutePath) async {
    if (_referenceImageCache.containsKey(absolutePath) ||
        _referenceImageLoading.contains(absolutePath) ||
        _referenceImageFailed.contains(absolutePath)) {
      return;
    }
    _referenceImageLoading.add(absolutePath);
    try {
      final bytes = await File(absolutePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      _updateState(() {
        _referenceImageCache[absolutePath] = frame.image;
        _referenceImageLoading.remove(absolutePath);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _updateState(() {
        _referenceImageLoading.remove(absolutePath);
        _referenceImageFailed.add(absolutePath);
      });
    }
  }

  Rect _referenceRect({
    required double scale,
    required Size viewportSize,
    required _ResolvedReferenceVisual reference,
  }) {
    final origin = _ViewportGeometry.canvasCenter(
      viewportSize,
      _viewportPanPixels,
    );
    final width = math.max(
      1.0,
      reference.frameWidth * reference.renderScale * scale,
    );
    final height = math.max(
      1.0,
      reference.frameHeight * reference.renderScale * scale,
    );
    final left = origin.dx - (reference.anchorX * width);
    final top = origin.dy - (reference.anchorY * height);
    return Rect.fromLTWH(left, top, width, height);
  }

  void _applyZoomDelta(double delta) {
    final nextZoom = (_viewportZoom + delta).clamp(
      _EditorHomePageState._viewportMinZoom,
      _EditorHomePageState._viewportMaxZoom,
    );
    if ((nextZoom - _viewportZoom).abs() <=
        _EditorHomePageState._valueEpsilon) {
      return;
    }
    _updateState(() {
      _viewportZoom = nextZoom;
    });
  }

  void _resetViewportTransform() {
    _updateState(() {
      _viewportZoom = 1.0;
      _viewportPanPixels = Offset.zero;
      _panSession = null;
    });
  }

  KeyEventResult _handleViewportKeyEvent(
    KeyEvent event,
    ColliderEntry selectedEntry,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_dragSession != null || _panSession != null) {
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    final shiftPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );
    final altPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altRight,
        );
    final baseStep = _resolvedSnapStep() ?? 0.25;
    final step = shiftPressed ? baseStep * 4.0 : baseStep;

    var axisX = 0.0;
    var offsetAxisY = 0.0;
    var extentAxisY = 0.0;
    if (key == LogicalKeyboardKey.arrowLeft) {
      axisX = -1.0;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      axisX = 1.0;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      // Runtime world uses Y-down: move up means negative offsetY.
      offsetAxisY = -1.0;
      // For extent editing, keep "up increases height".
      extentAxisY = 1.0;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      // Runtime world uses Y-down: move down means positive offsetY.
      offsetAxisY = 1.0;
      // For extent editing, keep "down decreases height".
      extentAxisY = -1.0;
    } else {
      return KeyEventResult.ignored;
    }

    var halfX = selectedEntry.halfX;
    var halfY = selectedEntry.halfY;
    var offsetX = selectedEntry.offsetX;
    var offsetY = selectedEntry.offsetY;

    if (altPressed) {
      if (axisX != 0) {
        halfX = _snapHalfExtent(halfX + axisX * step);
      }
      if (extentAxisY != 0) {
        halfY = _snapHalfExtent(halfY + extentAxisY * step);
      }
    } else {
      if (axisX != 0) {
        offsetX = _snapValue(offsetX + axisX * step);
      }
      if (offsetAxisY != 0) {
        offsetY = _snapValue(offsetY + offsetAxisY * step);
      }
    }

    _dragSession = null;
    _panSession = null;
    _clearDraft();
    _applyEntryValues(
      selectedEntry.id,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
    );
    return KeyEventResult.handled;
  }

  void _startViewportInteraction(
    ColliderEntry selectedEntry,
    ColliderEntry previewEntry,
    Size viewportSize,
    double scale,
    Offset localPosition,
  ) {
    final handle = _hitTestViewportHandle(
      localPosition: localPosition,
      size: viewportSize,
      entry: previewEntry,
      scale: scale,
      panPixels: _viewportPanPixels,
    );
    if (handle != null) {
      _setDraftFromEntry(previewEntry);
      _updateState(() {
        _panSession = null;
        _dragSession = _ViewportDragSession(
          entryId: selectedEntry.id,
          handle: handle,
          startPointer: localPosition,
          scale: scale,
          size: viewportSize,
          panPixels: _viewportPanPixels,
          startHalfX: previewEntry.halfX,
          startHalfY: previewEntry.halfY,
          startOffsetX: previewEntry.offsetX,
          startOffsetY: previewEntry.offsetY,
        );
      });
      return;
    }

    _updateState(() {
      _dragSession = null;
      _panSession = _ViewportPanSession(
        startPointer: localPosition,
        startPanPixels: _viewportPanPixels,
      );
      _clearDraft();
    });
  }

  void _updateViewportInteraction(Offset localPosition) {
    final panSession = _panSession;
    if (panSession != null) {
      _updateState(() {
        _viewportPanPixels =
            panSession.startPanPixels +
            (localPosition - panSession.startPointer);
      });
      return;
    }

    final session = _dragSession;
    if (session == null) {
      return;
    }

    final currentHalfX = _draftHalfX ?? session.startHalfX;
    final currentHalfY = _draftHalfY ?? session.startHalfY;
    final currentOffsetX = _draftOffsetX ?? session.startOffsetX;
    final currentOffsetY = _draftOffsetY ?? session.startOffsetY;

    var nextHalfX = currentHalfX;
    var nextHalfY = currentHalfY;
    var nextOffsetX = currentOffsetX;
    var nextOffsetY = currentOffsetY;

    final center = _ViewportGeometry.colliderCenter(
      session.size,
      currentOffsetX,
      currentOffsetY,
      session.scale,
      session.panPixels,
    );

    switch (session.handle) {
      case _ViewportDragHandle.center:
        final dx = (localPosition.dx - session.startPointer.dx) / session.scale;
        final dy = (localPosition.dy - session.startPointer.dy) / session.scale;
        nextOffsetX = _snapValue(session.startOffsetX + dx);
        nextOffsetY = _snapValue(session.startOffsetY + dy);
        break;
      case _ViewportDragHandle.rightEdge:
        final candidate = (localPosition.dx - center.dx) / session.scale;
        nextHalfX = _snapHalfExtent(candidate);
        break;
      case _ViewportDragHandle.topEdge:
        final candidate = (center.dy - localPosition.dy) / session.scale;
        nextHalfY = _snapHalfExtent(candidate);
        break;
    }

    _updateState(() {
      _draftHalfX = nextHalfX;
      _draftHalfY = nextHalfY;
      _draftOffsetX = nextOffsetX;
      _draftOffsetY = nextOffsetY;
      _syncInspectorFromValues(
        halfX: nextHalfX,
        halfY: nextHalfY,
        offsetX: nextOffsetX,
        offsetY: nextOffsetY,
      );
    });
  }

  void _finishViewportInteraction() {
    if (_panSession != null) {
      _updateState(() {
        _panSession = null;
      });
      return;
    }

    final session = _dragSession;
    _updateState(() {
      _dragSession = null;
    });
    if (session == null) {
      return;
    }

    final scene = widget.controller.colliderScene;
    if (scene == null) {
      _clearDraft();
      return;
    }
    final selectedEntry = _selectedEntry(scene);
    if (selectedEntry == null) {
      _clearDraft();
      return;
    }
    if (selectedEntry.id != session.entryId) {
      _clearDraft();
      return;
    }

    _commitDraftToController(selectedEntry);
    _clearDraft();
  }

  void _cancelViewportInteraction() {
    _updateState(() {
      _dragSession = null;
      _panSession = null;
    });
    final scene = widget.controller.colliderScene;
    final selectedEntry = scene == null ? null : _selectedEntry(scene);
    _clearDraft();
    if (selectedEntry != null) {
      _syncInspectorFromEntry(selectedEntry);
    }
  }

  _ViewportDragHandle? _hitTestViewportHandle({
    required Offset localPosition,
    required Size size,
    required ColliderEntry entry,
    required double scale,
    required Offset panPixels,
  }) {
    const hitRadius = 16.0;
    final center = _ViewportGeometry.colliderCenter(
      size,
      entry.offsetX,
      entry.offsetY,
      scale,
      panPixels,
    );
    final right = _ViewportGeometry.rightHandle(center, entry.halfX, scale);
    final top = _ViewportGeometry.topHandle(center, entry.halfY, scale);

    final candidates = <(_ViewportDragHandle, Offset)>[
      (_ViewportDragHandle.center, center),
      (_ViewportDragHandle.rightEdge, right),
      (_ViewportDragHandle.topEdge, top),
    ];
    for (final candidate in candidates) {
      final distance = (candidate.$2 - localPosition).distance;
      if (distance <= hitRadius) {
        return candidate.$1;
      }
    }
    return null;
  }

  void _setDraftFromEntry(ColliderEntry entry) {
    _draftEntryId = entry.id;
    _draftHalfX = entry.halfX;
    _draftHalfY = entry.halfY;
    _draftOffsetX = entry.offsetX;
    _draftOffsetY = entry.offsetY;
  }

  void _clearDraft() {
    _draftEntryId = null;
    _draftHalfX = null;
    _draftHalfY = null;
    _draftOffsetX = null;
    _draftOffsetY = null;
  }

  void _commitDraftToController(ColliderEntry baseline) {
    if (_draftEntryId != baseline.id) {
      return;
    }
    final halfX = _draftHalfX ?? baseline.halfX;
    final halfY = _draftHalfY ?? baseline.halfY;
    final offsetX = _draftOffsetX ?? baseline.offsetX;
    final offsetY = _draftOffsetY ?? baseline.offsetY;

    if ((halfX - baseline.halfX).abs() <= _EditorHomePageState._valueEpsilon &&
        (halfY - baseline.halfY).abs() <= _EditorHomePageState._valueEpsilon &&
        (offsetX - baseline.offsetX).abs() <=
            _EditorHomePageState._valueEpsilon &&
        (offsetY - baseline.offsetY).abs() <=
            _EditorHomePageState._valueEpsilon) {
      return;
    }

    _applyEntryValues(
      baseline.id,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  void _syncInspectorFromValues({
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
  }) {
    _halfXController.text = halfX.toStringAsFixed(2);
    _halfYController.text = halfY.toStringAsFixed(2);
    _offsetXController.text = offsetX.toStringAsFixed(2);
    _offsetYController.text = offsetY.toStringAsFixed(2);
  }
}

class _ResolvedReferenceVisual {
  const _ResolvedReferenceVisual({
    required this.frameWidth,
    required this.frameHeight,
    required this.renderScale,
    required this.anchorX,
    required this.anchorY,
    required this.defaultAnimKey,
    required this.animViewsByKey,
  });

  final double frameWidth;
  final double frameHeight;
  final double renderScale;
  final double anchorX;
  final double anchorY;
  final String? defaultAnimKey;
  final Map<String, _ResolvedReferenceAnimView> animViewsByKey;

  List<String> get animKeys => List<String>.unmodifiable(animViewsByKey.keys);

  String? resolveAnimKey(String? preferredKey) {
    if (preferredKey != null && animViewsByKey.containsKey(preferredKey)) {
      return preferredKey;
    }
    final fallbackKey = defaultAnimKey;
    if (fallbackKey != null && animViewsByKey.containsKey(fallbackKey)) {
      return fallbackKey;
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }
    return animViewsByKey.keys.first;
  }
}

class _ResolvedReferenceAnimView {
  const _ResolvedReferenceAnimView({
    required this.key,
    required this.absolutePath,
    required this.displayPath,
    required this.defaultRow,
    required this.defaultFrameStart,
    required this.defaultFrameCount,
    required this.defaultGridColumns,
  });

  final String key;
  final String absolutePath;
  final String displayPath;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;

  int? get maxFrameIndex {
    final count = defaultFrameCount;
    if (count == null || count <= 0) {
      return null;
    }
    return defaultFrameStart + count - 1;
  }
}

enum _ViewportDragHandle { center, rightEdge, topEdge }

class _ViewportDragSession {
  const _ViewportDragSession({
    required this.entryId,
    required this.handle,
    required this.startPointer,
    required this.scale,
    required this.size,
    required this.panPixels,
    required this.startHalfX,
    required this.startHalfY,
    required this.startOffsetX,
    required this.startOffsetY,
  });

  final String entryId;
  final _ViewportDragHandle handle;
  final Offset startPointer;
  final double scale;
  final Size size;
  final Offset panPixels;
  final double startHalfX;
  final double startHalfY;
  final double startOffsetX;
  final double startOffsetY;
}

class _ViewportPanSession {
  const _ViewportPanSession({
    required this.startPointer,
    required this.startPanPixels,
  });

  final Offset startPointer;
  final Offset startPanPixels;
}

class _ReferenceFramePainter extends CustomPainter {
  const _ReferenceFramePainter({
    required this.image,
    required this.row,
    required this.frame,
    required this.destinationRect,
    required this.anchorX,
    required this.anchorY,
    required this.showReferencePoints,
    required this.frameWidth,
    required this.frameHeight,
    required this.gridColumns,
    this.drawMarkerLabels = true,
  });

  final ui.Image image;
  final int row;
  final int frame;
  final Rect destinationRect;
  final double anchorX;
  final double anchorY;
  final bool showReferencePoints;
  final double frameWidth;
  final double frameHeight;
  final int? gridColumns;
  final bool drawMarkerLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final safeFrameWidth = math.max(1.0, frameWidth);
    final safeFrameHeight = math.max(1.0, frameHeight);

    final maxColumns = math.max(1, (image.width / safeFrameWidth).floor());
    final maxRows = math.max(1, (image.height / safeFrameHeight).floor());
    final requestedFrame = frame < 0 ? 0 : frame;
    final requestedRow = row < 0 ? 0 : row;

    final columns = gridColumns != null && gridColumns! > 0
        ? gridColumns!
        : maxColumns;
    final rowOffset = requestedFrame ~/ columns;
    final columnIndex = requestedFrame % columns;
    final sourceRow = (requestedRow + rowOffset).clamp(0, maxRows - 1);
    final sourceColumn = columnIndex.clamp(0, maxColumns - 1);
    final sourceRect = Rect.fromLTWH(
      sourceColumn * safeFrameWidth,
      sourceRow * safeFrameHeight,
      safeFrameWidth,
      safeFrameHeight,
    );
    if (destinationRect.width <= 0 || destinationRect.height <= 0) {
      return;
    }
    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      Paint()
        // Use filtered minification in editor preview so zoomed-out frames keep
        // a stable visual centroid instead of "pixel-drop" apparent drift.
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );

    if (!showReferencePoints) {
      return;
    }

    final clampedAnchorX = anchorX.clamp(0.0, 1.0);
    final clampedAnchorY = anchorY.clamp(0.0, 1.0);
    final anchorPoint = Offset(
      destinationRect.left + destinationRect.width * clampedAnchorX,
      destinationRect.top + destinationRect.height * clampedAnchorY,
    );
    final frameCenter = destinationRect.center;

    final guidePaint = Paint()
      ..color = const Color(0xCCFFD85A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(frameCenter, anchorPoint, guidePaint);

    final centerFill = Paint()..color = const Color(0xCC9AD9FF);
    final centerStroke = Paint()
      ..color = const Color(0xFF0B141C)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(frameCenter, 3.8, centerFill);
    canvas.drawCircle(frameCenter, 3.8, centerStroke);

    final anchorStroke = Paint()
      ..color = const Color(0xFFFFE07D)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const arm = 5.0;
    canvas.drawLine(
      Offset(anchorPoint.dx - arm, anchorPoint.dy),
      Offset(anchorPoint.dx + arm, anchorPoint.dy),
      anchorStroke,
    );
    canvas.drawLine(
      Offset(anchorPoint.dx, anchorPoint.dy - arm),
      Offset(anchorPoint.dx, anchorPoint.dy + arm),
      anchorStroke,
    );
    canvas.drawCircle(anchorPoint, 4.8, anchorStroke);
    if (drawMarkerLabels) {
      _paintPointLabel(canvas, frameCenter, 'F', const Color(0xFF9AD9FF));
      _paintPointLabel(canvas, anchorPoint, 'A', const Color(0xFFFFE07D));
    }
  }

  void _paintPointLabel(
    Canvas canvas,
    Offset point,
    String label,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xFF0B141C),
              blurRadius: 2,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelOffset = point + const Offset(7, -14);
    textPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _ReferenceFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.row != row ||
        oldDelegate.frame != frame ||
        oldDelegate.destinationRect != destinationRect ||
        oldDelegate.anchorX != anchorX ||
        oldDelegate.anchorY != anchorY ||
        oldDelegate.showReferencePoints != showReferencePoints ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.gridColumns != gridColumns ||
        oldDelegate.drawMarkerLabels != drawMarkerLabels;
  }
}

class _ColliderViewportPainter extends CustomPainter {
  const _ColliderViewportPainter({
    required this.entry,
    required this.scale,
    required this.gridCellSize,
    required this.panPixels,
    required this.activeHandle,
    this.drawGridAndAxes = true,
    this.drawColliderFill = true,
    this.drawColliderOutline = true,
    this.drawHandles = true,
    this.fillColor = const Color(0x5522D3EE),
  });

  final ColliderEntry entry;
  final double scale;
  final double gridCellSize;
  final Offset panPixels;
  final _ViewportDragHandle? activeHandle;
  final bool drawGridAndAxes;
  final bool drawColliderFill;
  final bool drawColliderOutline;
  final bool drawHandles;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasCenter = _ViewportGeometry.canvasCenter(size, panPixels);
    if (drawGridAndAxes) {
      final gridPaint = Paint()
        ..color = const Color(0xFF233444)
        ..strokeWidth = 1;
      final axisPaint = Paint()
        ..color = const Color(0xFF3A566E)
        ..strokeWidth = 1.2;
      _paintWorldGrid(
        canvas,
        size,
        canvasCenter: canvasCenter,
        gridPaint: gridPaint,
      );
      canvas.drawLine(
        Offset(0, canvasCenter.dy),
        Offset(size.width, canvasCenter.dy),
        axisPaint,
      );
      canvas.drawLine(
        Offset(canvasCenter.dx, 0),
        Offset(canvasCenter.dx, size.height),
        axisPaint,
      );
    }

    final colliderCenter = _ViewportGeometry.colliderCenter(
      size,
      entry.offsetX,
      entry.offsetY,
      scale,
      panPixels,
    );
    final colliderRect = _ViewportGeometry.colliderRect(
      center: colliderCenter,
      halfX: entry.halfX,
      halfY: entry.halfY,
      scale: scale,
    );
    if (drawColliderFill) {
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRect(colliderRect, fillPaint);
    }
    if (drawColliderOutline) {
      final strokePaint = Paint()
        ..color = const Color(0xFF7CE5FF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(colliderRect, strokePaint);
    }

    if (drawHandles) {
      final centerHandle = colliderCenter;
      final rightHandle = _ViewportGeometry.rightHandle(
        colliderCenter,
        entry.halfX,
        scale,
      );
      final topHandle = _ViewportGeometry.topHandle(
        colliderCenter,
        entry.halfY,
        scale,
      );
      _paintHandle(
        canvas,
        centerHandle,
        kind: _ViewportDragHandle.center,
        activeKind: activeHandle,
        color: const Color(0xFFE9B949),
        label: 'C',
      );
      _paintHandle(
        canvas,
        rightHandle,
        kind: _ViewportDragHandle.rightEdge,
        activeKind: activeHandle,
        color: const Color(0xFF9BDEAC),
        label: 'R',
      );
      _paintHandle(
        canvas,
        topHandle,
        kind: _ViewportDragHandle.topEdge,
        activeKind: activeHandle,
        color: const Color(0xFFBCA6FF),
        label: 'T',
      );
    }
  }

  void _paintHandle(
    Canvas canvas,
    Offset center, {
    required _ViewportDragHandle kind,
    required _ViewportDragHandle? activeKind,
    required Color color,
    required String label,
  }) {
    final isActive = kind == activeKind;
    final fill = Paint()
      ..color = isActive ? color : color.withValues(alpha: 0.8);
    final stroke = Paint()
      ..color = const Color(0xFF0B141C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final radius = isActive ? 8.0 : 6.5;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
    _paintHandleLabel(canvas, center, label, color);
  }

  void _paintHandleLabel(
    Canvas canvas,
    Offset center,
    String label,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xFF0B141C),
              blurRadius: 2,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center + const Offset(8, -14));
  }

  void _paintWorldGrid(
    Canvas canvas,
    Size size, {
    required Offset canvasCenter,
    required Paint gridPaint,
  }) {
    if (!gridCellSize.isFinite || gridCellSize <= 0 || !scale.isFinite) {
      return;
    }
    final baseSpacingPx = gridCellSize * scale;
    if (!baseSpacingPx.isFinite || baseSpacingPx <= 0) {
      return;
    }

    // Keep line count bounded at low zoom while staying aligned to world cells.
    var cellStride = 1;
    if (baseSpacingPx < 12.0) {
      cellStride = (12.0 / baseSpacingPx).ceil();
    }
    final spacingPx = baseSpacingPx * cellStride;

    final minKX = ((0 - canvasCenter.dx) / spacingPx).floor() - 1;
    final maxKX = ((size.width - canvasCenter.dx) / spacingPx).ceil() + 1;
    for (var k = minKX; k <= maxKX; k += 1) {
      final x = canvasCenter.dx + (k * spacingPx);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final minKY = ((0 - canvasCenter.dy) / spacingPx).floor() - 1;
    final maxKY = ((size.height - canvasCenter.dy) / spacingPx).ceil() + 1;
    for (var k = minKY; k <= maxKY; k += 1) {
      final y = canvasCenter.dy + (k * spacingPx);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ColliderViewportPainter oldDelegate) {
    return oldDelegate.entry.halfX != entry.halfX ||
        oldDelegate.entry.halfY != entry.halfY ||
        oldDelegate.entry.offsetX != entry.offsetX ||
        oldDelegate.entry.offsetY != entry.offsetY ||
        oldDelegate.scale != scale ||
        oldDelegate.gridCellSize != gridCellSize ||
        oldDelegate.panPixels != panPixels ||
        oldDelegate.activeHandle != activeHandle ||
        oldDelegate.drawGridAndAxes != drawGridAndAxes ||
        oldDelegate.drawColliderFill != drawColliderFill ||
        oldDelegate.drawColliderOutline != drawColliderOutline ||
        oldDelegate.drawHandles != drawHandles ||
        oldDelegate.fillColor != fillColor;
  }
}

class _ViewportGeometry {
  static Offset canvasCenter(Size size, Offset panPixels) =>
      Offset(size.width * 0.5, size.height * 0.5) + panPixels;

  static Offset colliderCenter(
    Size size,
    double offsetX,
    double offsetY,
    double scale,
    Offset panPixels,
  ) {
    final canvasMid = canvasCenter(size, panPixels);
    return Offset(
      canvasMid.dx + offsetX * scale,
      // Match runtime convention (Core + Flame): Y increases downward.
      canvasMid.dy + offsetY * scale,
    );
  }

  static Rect colliderRect({
    required Offset center,
    required double halfX,
    required double halfY,
    required double scale,
  }) {
    final halfWidth = halfX * scale;
    final halfHeight = halfY * scale;
    return Rect.fromLTRB(
      center.dx - halfWidth,
      center.dy - halfHeight,
      center.dx + halfWidth,
      center.dy + halfHeight,
    );
  }

  static Offset rightHandle(Offset center, double halfX, double scale) =>
      Offset(center.dx + halfX * scale, center.dy);

  static Offset topHandle(Offset center, double halfY, double scale) =>
      Offset(center.dx, center.dy - halfY * scale);
}
