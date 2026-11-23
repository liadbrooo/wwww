import Foundation
@main struct Tests {
    static func main() {
        var p=Project()
        let clip=Clip(name:"Test",kind:.video,start:2,sourceIn:3,length:10,speed:2)
        p.clips=[clip]
        precondition(p.duration == 12)
        guard let id=p.split(clip.id,at:6),let right=p.clips.first(where:{$0.id==id}) else {fatalError("Split failed")}
        precondition(right.start==6 && right.sourceIn==11 && right.length==6)
        precondition(p.clips.first?.length==4 && p.duration==12)
        precondition(p.split(id,at:6)==nil)
        let data=try! JSONEncoder().encode(p)
        precondition(try! JSONDecoder().decode(Project.self,from:data)==p)
        print("Project model tests passed")
    }
}
