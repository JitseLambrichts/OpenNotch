import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SafeSpaceWidgetView: View {
    @Bindable var manager = SafeSpaceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if manager.items.isEmpty {
                        Text("Drop files anywhere here to store temporarily")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(manager.items) { item in
                            SafeSpaceItemView(item: item)
                                .onDrag {
                                    // Use the stored temporary file for dragging out
                                    return NSItemProvider(object: item.temporaryURL as NSURL)
                                }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 60)
            }
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        // Accept dropped files
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                        if let error = error {
                            print("SafeSpace Drop Error: \(error.localizedDescription)")
                            return
                        }

                        var droppedURL: URL?

                        if let data = item as? Data {
                            droppedURL = URL(dataRepresentation: data, relativeTo: nil)
                        } else if let url = item as? URL {
                            // Sometimes item is directly a URL
                            droppedURL = url
                        } else if let nsurl = item as? NSURL {
                            // Sometimes item is an NSURL
                            droppedURL = nsurl as URL
                        }

                        if let url = droppedURL {
                            print("SafeSpace Drop Success! Got URL: \(url.path)")
                            DispatchQueue.main.async {
                                SafeSpaceManager.shared.add(urls: [url])
                            }
                        } else {
                            print("SafeSpace Drop Warning: Could not extract URL from item: \(String(describing: item))")
                        }
                    }
                }
            }
            return true
        }
    }
}

struct SafeSpaceItemView: View {
    let item: SafeSpaceItem
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: item.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding(8)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(8)

                if isHovering {
                    Button(action: {
                        SafeSpaceManager.shared.remove(item: item)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.primary)
                            .background(Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: 4, y: -4)
                }
            }

            Text(item.name)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 56)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Remove") {
                SafeSpaceManager.shared.remove(item: item)
            }
            Button("Clear All") {
                SafeSpaceManager.shared.clearAllItems()
            }
        }
    }
}