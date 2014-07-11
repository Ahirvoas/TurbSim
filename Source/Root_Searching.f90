MODULE NEWTON_MOD
PUBLIC :: F, FP
CONTAINS
FUNCTION F(X,URef,RefHt,HubHt) RESULT (Y)
REAL, INTENT(IN) :: X
!REAL, INTENT(IN) :: V_10
REAL, INTENT(IN) :: URef
REAL, INTENT(IN) :: RefHt
REAL, INTENT(IN) :: HubHt
REAL :: Y
REAL :: C_1
REAL :: C_2
REAL :: D_1
REAL :: D_2
REAL :: D_3
REAL :: D_4
IF (RefHt==10.0) THEN
C_1=1.0-0.41*0.06*LOG(600.0/3600.0)
C_2=0.41*0.06*0.043*LOG(600.0/3600.0)
Y=C_1*X-C_2*X*X-URef
ELSEIF (RefHt==HubHt)  THEN
D_1=1.0-0.41*0.06*LOG(600.0/3600.0)*(RefHt/10.0)**(-0.22)
D_2=0.41*0.06*0.043*LOG(600.0/3600.0)*(RefHt/10.0)**(-0.22)
D_3=D_1*0.0573*LOG(RefHt/10.0)
D_4=D_2*0.0573*LOG(RefHt/10.0)
Y=D_1*X-D_2*X*X+D_3*X*(1.0+0.15*X)**0.5-D_4*X*X*(1.0+0.15*X)**0.5-URef    
ELSE
   Y = -9999999   
ENDIF

END FUNCTION F
FUNCTION FP(X,URef,RefHt,HubHt) RESULT (Y)
REAL, INTENT(IN) :: X
REAL, INTENT(IN) :: URef
REAL, INTENT(IN) :: RefHt
REAL, INTENT(IN) :: HubHt
REAL :: Y
REAL :: C_1
REAL :: C_2
REAL :: D_1
REAL :: D_2
REAL :: D_3
REAL :: D_4
IF (RefHt==10.0) THEN
C_1=1.0-0.41*0.06*LOG(600.0/3600.0)
C_2=0.41*0.06*0.043*LOG(600.0/3600.0)
Y=C_1-2.0*C_2*X
ELSEIF (RefHt==HubHt)  THEN
C_1=1.0-0.41*0.06*LOG(600.0/3600.0)
C_2=0.41*0.06*0.043*LOG(600.0/3600.0)
D_1=1.0-0.41*0.06*LOG(600.0/3600.0)*(RefHt/10.0)**(-0.22)
D_2=0.41*0.06*0.043*LOG(600.0/3600.0)*(RefHt/10.0)**(-0.22)
D_3=D_1*0.0573*LOG(RefHt/10.0)
D_4=D_2*0.0573*LOG(RefHt/10.0)
Y=D_1-2.0*D_2*X+D_3*((1.0+0.15*X)**0.5+0.15*X/2.0/(1.0+0.15*X)**0.5)  &
-D_4*(2.0*X*(1.0+0.15*X)**0.5+0.15*X*X/2.0/(1.0+0.15*X)**0.5)
ELSE
   Y = -9999999
ENDIF

END FUNCTION FP
END MODULE NEWTON_MOD
    
    
SUBROUTINE ROOT_SEARCHING(X0,X,URef,RefHt,HubHt)
USE NEWTON_MOD
REAL, PARAMETER :: TOL=1.0E-5
REAL, INTENT(IN) :: URef
REAL, INTENT(IN) :: RefHt
REAL, INTENT(IN) :: HubHt
REAL, INTENT(IN)  :: X0
REAL, INTENT(OUT) :: X

X=X0
DO  ! bjj: I'd like this better if there were absolutely no way to have an infinite loop here...
   X = X - F(X,URef,RefHt,HubHt) / FP(X,URef,RefHt,HubHt)
   IF (ABS(F(X,URef,RefHt,HubHt))<TOL) THEN
      EXIT
   END IF
   
END DO
END SUBROUTINE ROOT_SEARCHING
    
    

    