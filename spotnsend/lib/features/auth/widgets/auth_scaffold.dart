import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:spotnsend/core/theme/gradients.dart';

import 'auth_header.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.showBackButton = false,
    this.maxContentWidth = 520,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final bool showBackButton;
  final double maxContentWidth;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  if (onBack != null) {
                    onBack!();
                    return;
                  }
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompactHeight = constraints.maxHeight < 720;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    vertical: isCompactHeight ? 12 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.94),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 40,
                                offset: const Offset(0, 26),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthGradientHeader(
                                title: title,
                                subtitle: subtitle,
                                compact: isCompactHeight,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 24, 24, 16),
                                child: body,
                              ),
                              if (footer != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                  child: footer!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
