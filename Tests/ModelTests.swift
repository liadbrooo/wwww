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
        var q=Project()
        let portrait=Media(path:"test",name:"test",duration:2,kind:.video,width:1080,height:1920,fps:29.97002997)
        q.useSource(portrait)
        precondition(q.renderSize.width==1080 && q.renderSize.height==1920)
        precondition(abs(q.frameRate-29.97)<0.001)
        q.ultraHD=true
        precondition(q.renderSize.width==2160 && q.renderSize.height==3840)
        var animated=Clip(name:"Motion",kind:.video,length:2)
        animated.keyframes=[Keyframe(time:0,scale:1,x:0,y:0,rotation:0,opacity:1,ease:.linear),Keyframe(time:2,scale:3,x:1,y:0,rotation:180,opacity:0)]
        precondition(animated.pose(at:1).scale==2 && animated.pose(at:1).opacity==0.5)
        precondition(abs(q.snap(10.017)-((10.017*q.frameRate).rounded()/q.frameRate))<0.00001)
        var stack=animated
        stack.effect = .blur;stack.intensity=0.2
        precondition(stack.effectStack.first?.effect == .blur)
        stack.effects=[EffectLayer(effect:.blur),EffectLayer(effect:.bloom)]
        precondition(stack.effectStack.count==2)
        stack.setPose(Keyframe(time:1,scale:2,x:0,y:0,rotation:0,opacity:1),at:1,fps:30)
        precondition(stack.pose(at:1).scale==2)
        var group=Project()
        group.addTrack(audio:false);group.addTrack(audio:true)
        precondition(group.lanes.first==3 && group.lanes.last == -3)
        let a=Clip(name:"A",kind:.video,start:0,length:2)
        let b=Clip(name:"B",kind:.video,start:2,length:2)
        group.clips=[a,b]
        precondition(group.moveGroup(Set([a.id,b.id]),delta:1,laneDelta:1))
        precondition(group.clips[0].start==1 && group.clips[1].start==3)
        group.toggleTrack(1,\.lockedTracks)
        precondition(!group.moveGroup(Set([a.id,b.id]),delta:1,laneDelta:0))
        group.removeGroup(Set([a.id]),ripple:false)
        precondition(group.clips.count==2)
        group.toggleTrack(1,\.lockedTracks)
        group.removeGroup(Set([a.id]),ripple:true)
        precondition(group.clips.count==1 && group.clips[0].start==1)
        print("Project model tests passed")
    }
}
