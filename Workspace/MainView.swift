import SwiftUI
import SwiftData

struct MainWorkspaceView: View {
    let project: WritingProject

    var body: some View {
        switch project.type {
        case .book:
            BookWorkspace(project: project)
        case .visualNovel:
            NovelWorkspace(project: project)
        case .screenplay:
            ScreenplayWorkspace(project: project)
        case .scientific:
            ScienceWorkspace(project: project)
        }
    }
}
