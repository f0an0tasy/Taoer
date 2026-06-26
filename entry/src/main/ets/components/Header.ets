import { router } from "@kit.ArkUI"

@Component
export struct Header {
  @Prop title:string
  onClickF:()=>void = ()=>{}
  build() {
    Row(){
      Image($r('app.media.icon_back'))
        .width(25)
        .aspectRatio(1)
        .onClick(()=>{
          this.onClickF()
          router.back()
        })

      Text(this.title)
        .fontSize(18)

      Text()
    }
    .width("100%")
    .justifyContent(FlexAlign.SpaceBetween)
    .padding(10)
    .backgroundColor(Color.White)

  }
}